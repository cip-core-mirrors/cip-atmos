# CIP Atmos

This repo extends the cloud posse atmos cli (https://github.com/cloudposse/atmos) to add cip's specific commands and package it along with the latest [atmos](https://atmos.tools/) command into a [geodesic](https://github.com/cloudposse/geodesic) container image.

## Using the image

A prebuilt image is available on [Quay.io](https://quay.io). To use it, run the image to generate the installation script:

```bash
$ docker run -it --rm quay.io/cipcore/cip-atmos | sudo bash
```

Then, to start the geodesic container using the startup script created by the previous command:

```bash
$ cip-atmos
```

## Build the image

You can build your own image with the following:

```bash
$ make docker/build
```