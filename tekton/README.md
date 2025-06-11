# Tekton Pipelines for Bootc Image Management

This document outlines a set of **Tekton Pipelines and Tasks** designed to automate the entire lifecycle of **`bootc` container images**, from building and signing to converting and deploying them as virtual machines within KubeVirt. It also includes event-driven triggers for seamless CI/CD.

## What It Does

This Tekton configuration provides an automated workflow for:

1.  **Building `bootc` Container Images**: Takes source code (typically a `Containerfile`) from a Git repository and builds it into a `bootc` container image.

2.  **Signing Images**: Digitally signs the built images using **Cosign** for supply chain security.

3.  **Converting Images**: Transforms the `bootc` container image into various formats, such as:

    * **QCOW2**: A standard disk image format for virtual machines.

    * **AWS AMI**: An Amazon Machine Image for deployment in AWS.

    * Other formats like `anaconda-iso`, `vmdk`, `raw`, `gcp`.

4.  **KubeVirt Integration**:

    * Prepares converted QCOW2 images for **KubeVirt ContainerDisk** usage.

    * **Deploys a KubeVirt VirtualMachine** directly from the `bootc` image, defining its CPU, memory, and disk size.

5.  **Event-Driven CI/CD**: Automatically triggers these workflows based on external events, primarily Git pushes.

## Key Components

### Pipelines

* **`bootc-image-builder`**: Converts an existing `bootc` container image into a desired format (e.g., QCOW2, AMI). It can optionally prepare and build a KubeVirt-ready container image.

* **`kubevirt-image-deploy`**: Deploys a specified QCOW2 image as a new VirtualMachine in your KubeVirt environment.

* **`centos-bootc-image-build`**: A focused pipeline to clone a Git repository, build a `bootc` container image, and sign it.

* **`bootc-end-to-end-pipeline`**: The most comprehensive pipeline, orchestrating the full flow: Git clone -> `bootc` build -> image sign -> format conversion -> KubeVirt preparation -> KubeVirt VM deployment.

### Tasks (Building Blocks)

These are reusable steps used within the pipelines:

* **`bootc-image-builder`**: Performs the core image conversion.

* **`bootc-image-build`**: Handles container image building and pushing with Podman.

* **`bootc-image-sign`**: Manages image signing using Cosign.

* **`kubevirt-containerfile`**: Creates a special `Containerfile` to package QCOW2 images for KubeVirt.

* **`kubernetes-actions`**: A versatile task for running any `kubectl` command, used here to deploy KubeVirt VMs.

### Triggers (Automation)

* **`image-build-listener`**: This is the webhook endpoint. It listens for incoming Git events (e.g., from Gitea).

* **Conditional Triggering**: Based on the Git branch name (specifically, if it contains "qcow"), the listener intelligently decides which pipeline to run:

    * If "qcow" is in the branch name: Triggers the full **`bootc-end-to-end-pipeline`** (build, sign, convert, deploy VM).

    * Otherwise: Triggers the **`centos-bootc-image-build`** pipeline (just build and sign the container image).

## How It Works

When a Git push occurs to your configured repository, the `image-build-listener` receives a webhook. It then analyzes the push event (e.g., the branch name) and initiates the appropriate Tekton PipelineRun. This kicks off a series of automated tasks that build, sign, convert, and potentially deploy your `bootc` images, all within your Kubernetes cluster.
