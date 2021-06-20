---
layout: post
title:  "Combining Etags with GZIP compression in Spring Boot"
date:   2021-06-20 21:00:00 +0100
tags: spring etag gzip
---

Adding Etags to the responses in a Spring Boot application is easy. 
Using GZIP to compress the responses in a Spring Boot application is easy as well.
There are plenty of blog posts available describing how to achieve either of them.

However, when I tried to combine them both the GZIP compression stopped working until I tweaked some settings.

In this post, I'll very briefly describe how to active GZIP and Etag, and then discuss in a bit more detail why and how you need to change the defaults to get them to play nice together.

## Activating GZIP compression

You can configure the standard Tomcat webserver in Spring Boot to GZIP the responses by adding the following to your YML properties file:

```YAML
 server:
  compression:
    enabled: true
```

## Activating ETags

Spring already has a filter that adds Etags to your responses. All you need to do is create a `Bean` for it:

```java
@Bean
public Filter shallowEtagHeaderFilter(){
  return new ShallowEtagHeaderFilter();
}
```

This will add a strong Etag header to your response.

The Etag is calculated from a hash based on the content of your response. 
As such, you need to make sure that your responses are deterministic.

In a first attempt of adding Etags to my responses for a JSON API, I always got a different Etag for the same request.
Turns out that Jackson used a random ordering for the properties when converting my Java objects to JSON.

One possible solution for this is to tell Jackson to use a fixed, alphabetical ordering:

```YAML
jackson:
  mapper:
    sort_properties_alphabetically: true
```

## Combining Etags with GZIP compression

Once you've configured Spring to add Etags to the responses, the GZIP compression for those responses will stop to work.

The reason is that the specification of a strong Etag says that a strong Etag is to be calculated not only over the body of the response, but also over some headers.
Including the header that specifies the encoding of the response.

As such, when Spring sends the response (including the stron Etag header) to Tomcat, the Tomcat server refuses to GZIP the response.
Compressing the response would mean that the encoding header is adjusted, hence Tomcat would suddenly become response to re-calculate the Etag.
And Tomcat doesn't know how to do that.

You can see this in the source code (relevant snippet copied from [`org.apache.coyote.CompressionConfig#useCompression`](https://github.com/apache/tomcat/blob/main/java/org/apache/coyote/CompressionConfig.java)):

```java
// Check if the resource has a strong ETag
String eTag = responseHeaders.getHeader("ETag");
if (eTag != null && !eTag.trim().startsWith("W/")) {
    // Has an ETag that doesn't start with "W/..." so it must be a
    // strong ETag
    return false;
}
```        

The discussion whether this behavior in Tomcat is wanted or not can be found in [their bugtracker](https://bz.apache.org/bugzilla/show_bug.cgi?id=63932).

One possible solution for this is to switch to weak Etags by calling the corresponding setter on the `ShallowEtagHeaderFilter`:

```java
@Bean
public Filter shallowEtagHeaderFilter(){
  ShallowEtagHeaderFilter filter = new ShallowEtagHeaderFilter();
  filter.setWriteWeakETag(true);
  return filter
}
```

## Summary

In summary, in order to combine ETags with GZIP compression in Spring using the embedded Tomcat webserver, you'll need to:

* Enable GZIP compression through the `server.compression.enabled` property
* Add a `ShallowEtagHeaderFilter`
* Use the `ShallowEtagHeaderFilter#setWriteWeakEtag` method to switch to weak Etags so that Tomcat doesn't refuse to GZIP your response