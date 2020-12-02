---
layout: post
title:  "Tuning the Material UI Dropzone component"
date:   2020-11-27 22:16:57 +0100
tags: react material-ui material-ui-dropzone dropzone
---

When looking to add a file upload using drag-and-drop to a Material-UI based React website, Google points you to the [material-ui-dropzone](https://github.com/Yuvaleros/material-ui-dropzone) package. 
Thanks to the documentation with a lot of sample code it is very easy to get it up-and-running. 
After using and testing it for a few days, there are however some tweaks that I needed to make it behave almost exactly like I want it.

I'll first why I wanted to change certain things. You'll find the code for the custom component at the bottom of this post.

## Removing the incorrect drag feedback

The default behavior of the dropzone is to show visual feedback to the user when the file they're about to drop doesn't match the installed file filter on the dropzone (see the `acceptedFiles` property). Due to the [limitations of drag-and-drop in the browser](https://github.com/react-dropzone/react-dropzone/tree/master/examples/accept#browser-limitations), this feedback is not always correct.

For example when testing on my machine with a filter configured to accept files with `.geojson` extension and a matching MIME type, I got:

- Safari indicated the file was valid, based on the extension. There was no MIME type info available.
- Firefox and Chrome both refused the file. Debugging showed that they neither had access to the file name (hence couldn't check the extension) and couldn't find the MIME type. You can use [this site](https://react-dropzone-mime-tester.netlify.app) to test whether the MIME type of a file can be found by the dropzone.
- Other files for which the MIME type could be detected (e.g. a CSV file) worked flawlessly in all browsers.

## Improved visual disabled state

You can easily disable the dropzone, but the default styling gave no visual indication of this.
It always looks enabled.

As you can customize the styling, I used the disabled text color from the Material-UI theme and used that for both the SVG icon as well as the text.
Further, I also replace the upload icon with a forbidden icon when disabling the widget.

## Replacing the alerts

The dropzone shows alerts when a file was successfully dropped or rejected.
While there is API to customize all the settings about those alerts, the widget uses its own [`Snackbar`](https://material-ui.com/components/snackbars/) component.
If your application already has a `Snackbar` for your own alerts, the alerts coming from the widget could overlap with your own alerts.

The good thing about the available API is that you can disable the showing of the alerts while still having access to them through a callback function. This allows you to show the alerts in your own `Snackbar` or through any other mechanism.

Here I opted to only show the failure alerts, and show them underneath the widget.
One of the reasons of doing this was to combine that "error zone" with feedback from Formik when using it in a form with validation.

## Integrating with Formik

In our application we use [Formik](https://formik.org) in combination with [Formik Material-UI](https://stackworx.github.io/formik-material-ui/) to create, validate and submit our forms.

One of the requirements for the dropzone was to integrate it with Formik which is only a matter of converting some Formik properties to dropzone properties and vice versa.

Seeing as the dropzone by default has no place to show error messages, I re-used the error zone where I show the error alerts for showing the validation errors.

## Code

```tsx
import {
  AlertType,
  DropzoneArea,
  DropzoneAreaProps,
} from "material-ui-dropzone";
import React, { useState } from "react";
import {
  createMuiTheme,
  MuiThemeProvider,
  useTheme,
} from "@material-ui/core/styles";
import Alert from "@material-ui/lab/Alert";
import { Box } from "@material-ui/core";
import { FieldProps, getIn } from "formik";

interface DropzoneProps
  extends FieldProps,
    Omit<DropzoneAreaProps, "name" | "value" | "error"> {
  disabled?: boolean;
}
/**
 * Convert the Formik properties to dropzone properties
 */
export function fieldToDropzoneArea({
  disabled,
  field: { name: fieldName, onChange: fieldOnChange, ...field },
  form: {
    setFieldValue: formSetFieldValue,
    setFieldTouched: formSetFieldTouched,
    getFieldMeta: formGetFieldMeta,
    ...form
  },
  onChange,
  ...props
}: DropzoneProps): DropzoneAreaProps {
  return {
    onChange: (loadedFiles: File[]) => {
      formSetFieldValue(fieldName, loadedFiles, true);
    },
    onDrop: () => {
      formSetFieldTouched(fieldName, true, true);
    },
    onDropRejected: () => {
      formSetFieldTouched(fieldName, true, true);
    },
    onDelete: () => {
      formSetFieldTouched(fieldName, true, true);
    },
    initialFiles: (formGetFieldMeta(fieldName).initialValue as File[]) ?? [],
    ...field,
    ...props,
  };
}

export const Dropzone: React.FC<DropzoneProps> = (props) => {
  const theme = useTheme();
  const [alert, setAlert] = useState<string | null>(null);

  // Use different styling for the enabled
  // and disabled version of the widget
  const enabledTheme = createMuiTheme(
    {
      overrides: {
        MuiDropzoneArea: {
          icon: {
            color: theme.palette.text.primary,
          },
          text: {
            color: theme.palette.text.primary,
          },
        },
      },
    },
    theme
  );
  const disabledTheme = createMuiTheme(
    {
      overrides: {
        MuiDropzoneArea: {
          icon: {
            color: theme.palette.text.disabled,
          },
          text: {
            color: theme.palette.text.disabled,
          },
        },
      },
    },
    theme
  );

  const fieldError = getIn(props.form.errors, props.field.name);
  const showError = getIn(props.form.touched, props.field.name) && !!fieldError;

  return (
    <MuiThemeProvider
      theme={
        props.disabled != null && props.disabled ? disabledTheme : enabledTheme
      }
    >
      <DropzoneArea
        {...fieldToDropzoneArea(props)}
        disableRejectionFeedback
        showAlerts={false}
        onAlert={(message: string, variant: AlertType) => {
          if (variant === "error") {
            setAlert(message);
          } else {
            setAlert(null);
          }
        }}
        {% raw %}dropzoneProps={{
          disabled: props.disabled ?? props.form.isSubmitting,
        }}{% endraw %}
      >
        {props.children}
      </DropzoneArea>
      {showError && alert == null && (
        <Box mt={1}>
          <Alert severity="error">{fieldError}</Alert>
        </Box>
      )}
      {alert != null && (
        <Box mt={1}>
          <Alert severity="error">{alert}</Alert>
        </Box>
      )}
    </MuiThemeProvider>
  );
};

Dropzone.displayName = "FormikMaterialUIDropZone";

```
which can be used in a Formik powered form as 

```tsx
<Field
  component={Dropzone}
  name="jsonFiles"
  filesLimit={1}
  acceptedFiles={[".geojson", "text/geojson"]}
  maxFileSize={1024 * 1024 * 1024 * 2}
  showFileNames
  Icon={disabled ? NotInterestedIcon : CloudUploadIcon}
  dropzoneText={
    disabled
      ? "File upload is currently disabled"
      : "Drag and drop a GeoJSON file here or click to browse for a file."
  }
  disabled={disabled}
/>
```