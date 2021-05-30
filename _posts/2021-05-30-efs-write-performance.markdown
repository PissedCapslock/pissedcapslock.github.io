---
layout: post
title:  "Write performance of Amazon EFS"
date:   2021-05-30 17:00:00 +0100
tags: aws efs
---

<style type='text/css'>
.float-container {
}

.float-child {
    width: 50%;
    float: left;
}  
</style>

In our cloud setup at [xyzt.ai](https://xyzt.ai) we store our data on [Amazon's Elastic File System (EFS)](https://aws.amazon.com/efs/) 
because we need a fast file system that can be shared between multiple machines or services.

Amazon [says](https://docs.aws.amazon.com/efs/latest/ug/performance.html) their EFS system offers you:

* 300 MB/s read speed for up to 72 minutes/day
* 100 MB/s write speed for up to 72 minutes/day

While certainly not as fast as an SSD, these speeds should have been fast enough for our use-case.
However, the performance we got during our initial tests were rather disappointing.
Our gut feeling was that we didn't quite reach that advertised 100 MB/s, so we did some experiments.

For those that don't want to go over all details, there is a [summary](#summary) at the end of the article.

## Setup

For all these experiments, we've used the following setup

* An empty EFS file system created with the default settings
* An EC2 instance with 8 vCPU and 16 GB of RAM.
  We didn't use a more powerful EC2 instance as our real setup runs on Fargate, and Fargate is at this time limited to an 8 vCPU machine.

## Large files

For large files (1GB), EFS behaves exactly as advertised and as expected:

* When writing on a single thread, you get 100 MB/s write speed
* When writing on two threads simultaneously, each thread can write at 50 MB/s so the total write speed is still 100 MB/s

<div class="float-container">

  <div class="float-child">
    <div id="largefiles_perthread"></div>
  </div>
  
  <div class="float-child">
    <div id="largefiles_combined"></div>
  </div>
  
</div>

<script>
 new roughViz.BarH({
    element: '#largefiles_perthread',
    data: {
      labels: ["4 threads", "3 threads", "2 threads", "1 thread"],
      values: [13, 27, 52, 102]
    },
    title: "Write speed per thread in MB/s",
    titleFontSize: '1rem'
});
 new roughViz.BarH({
    element: '#largefiles_combined',
    data: {
      labels: ["4 thread", "3 threads", "2 threads", "1 threads"],
      values: [104, 106, 103, 102]
    },
    title: "Combined write speed in MB/s",
    titleFontSize: '1rem'
});
</script>

## Small and medium files (single thread)

When the files become smaller, it doesn't seem possible to obtain the advertised 100MB/s write speed when only using a single thread.

<div id="mediumfiles_singlethread"></div>

<script>
  new roughViz.Scatter({
  element: '#mediumfiles_singlethread',
  data: '/static_files/efs-write-performance/mediumfiles_singlethread.csv',
  x: 'File size in MB',
  y: 'Write speed in MB/s',
  xLabel: 'File size (MB)',
  yLabel: 'Write speed (MB/s)',
  width: window.innerWidth/2,
  title: "Single thread write speed in MB/s"
})
</script>

For files smaller than 10 MB, you get writing speeds between 20 and 50 MB/s, which is up to 5 times slower than advertised.
Only when your files are bigger than 85 MB you consistently get writing speeds above 95 MB/s.

Things become even worse when your files are less than 1 MB in size:

<div id="smallfiles_singlethread"></div>

<script>
  new roughViz.Scatter({
  element: '#smallfiles_singlethread',
  data: '/static_files/efs-write-performance/smallfiles_singlethread.csv',
  x: 'File size in kB',
  y: 'Write speed in MB/s',
  xLabel: 'File size (kB)',
  yLabel: 'Write speed (MB/s)',
  width: window.innerWidth/2,
  title: "Single thread write speed in MB/s"
})
</script>

For files under 10 kB, you don't even reach 1 MB/s writing speed.


## Small and medium files (multiple threads)

When you can use multiple threads to write small files to EFS you can obtain huge performance gains.

The following measurements were taken by writing 1 MB files using multiple threads.

<div class="float-container">

  <div class="float-child">
    <div id="oneMB-multithread-perfile"></div>
  </div>
  
  <div class="float-child">
    <div id="oneMB-multithread-combined"></div>
  </div>
  
</div>

<script>
 new roughViz.BarH({
    element: '#oneMB-multithread-perfile',
    data: {
      labels: ["10 threads", "9 threads", "8 threads", "7 threads","6 threads", "5 threads", "4 threads", "3 threads","2 threads", "1 thread"],
      values: [11, 12, 14, 16, 16, 18, 20, 21, 22, 23]
    },
    title: "Write speed per thread in MB/s",
    titleFontSize: '1rem'
});
 new roughViz.BarH({
    element: '#oneMB-multithread-combined',
    data: {
      labels: ["10 threads", "9 threads", "8 threads", "7 threads","6 threads", "5 threads", "4 threads", "3 threads","2 threads", "1 thread"],
      values: [103, 105, 104, 105,93,86,77,61,43,23]
    },
    title: "Combined write speed in MB/s",
    titleFontSize: '1rem'
});
</script>

Once we start using 7 threads or more, we manage to max out the available 100 MB/s write speed.

However if we repeat the same experiment with a 500 kB file:

<div class="float-container">

  <div class="float-child">
    <div id="halfMB-multithread-perfile"></div>
  </div>
  
  <div class="float-child">
    <div id="halfMB-multithread-combined"></div>
  </div>
  
</div>

<script>
 new roughViz.BarH({
    element: '#halfMB-multithread-perfile',
    data: {
      labels: ["1024 threads", "128 threads", "64 threads", "32 threads","16 threads", "8 threads", "4 threads"],
      values: [0, 1, 1, 3, 6, 10, 14]
    },
    title: "Write speed per thread in MB/s",
    titleFontSize: '1rem'
});
 new roughViz.BarH({
    element: '#halfMB-multithread-combined',
    data: {
      labels: ["1024 threads", "128 threads", "64 threads", "32 threads","16 threads", "8 threads", "4 threads"],
      values: [87, 81, 79, 84,84,80,55]
    },
    title: "Combined write speed in MB/s",
    titleFontSize: '1rem'
});
</script>

We can reach up to 80 MB/s with 8 threads. 
After that, we can get it to around 90 MB/s by aggressively increasing the number of threads.
But no matter how many threads we use, we couldn't reach the 100 MB/s.

Note that our machine we were using only has 8 vCPU's.
Perhaps that a beefier machine results in some better performance.

As it is clear that beyond a certain number of threads the combined write speed over all threads reaches a plafond, we did one last experiment.
We used 128 threads to write small files and measured the combined write speed over all the threads:

<div id="smallfiles_multiplethreads"></div>

<script>
  new roughViz.Scatter({
  element: '#smallfiles_multiplethreads',
  data: '/static_files/efs-write-performance/smallfiles_multiplethreads.csv',
  x: 'File size in kB',
  y: 'Write speed in MB/s',
  xLabel: 'File size (kB)',
  yLabel: 'Write speed (MB/s)',
  width: window.innerWidth/2,
  title: "Combined write speed over all 128 threads in MB/s"
})
</script>

As the plot shows, for small sizes the writing performance remains far below the advertised 100 MB/s.
Even with files of 500kB in size, the best we achieved was around 80 MB/s.

Once we go beyond that, we can reach the 100 MB/s limit (when using 128 threads to write in parallel):

<div id="smallfiles_multiplethreads2"></div>

<script>
  new roughViz.Scatter({
  element: '#smallfiles_multiplethreads2',
  data: '/static_files/efs-write-performance/smallfiles_multiplethreads2.csv',
  x: 'File size in kB',
  y: 'Write speed in MB/s',
  xLabel: 'File size (kB)',
  yLabel: 'Write speed (MB/s)',
  width: window.innerWidth/2,
  title: "Combined write speed over all 128 threads in MB/s"
})
</script>

## Summary

From the performed experiments we can extract the following conclusions:

* When your files are smaller than 1 MB, you'll get the best performance by writing as many as you can in parallel.
* If your files are really small (0.5 MB or smaller), you won't get near the advertised 100 MB/s speed.
  Using multiple threads is still your best option.
* When your files are between 1 and 100 MB in size, you'll get the maximum writing speed if you use the following number of threads:
  * &gt; 80MB: a single thread
  * &gt; 40MB: 2 threads
  * &gt; 20MB: 4 threads
  * &gt; 1MB: 8 threads
* When your files are over 100 MB in size, a single thread can reach the 100 MB/s writing speed limit.
  If you use multiple threads to write multiple files in parallel, the available speed will be divided equally over all threads.  