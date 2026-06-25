# Avelo CI/CD Pipeline

This document explains the continuous integration and deployment pipeline for the Avelo project using GitHub Actions.

## How it works

The CI/CD pipeline is defined in `.github/workflows/build.yml`. It handles compiling the Flutter source code into native executables and packaging them into clean, runnable formats for distribution.

The pipeline consists of four main jobs:
1. **Build Linux (`build-linux`)**: Compiles the app for Linux and creates a tarball (`Avelo-Linux.tar.gz`).
2. **Build Windows (`build-windows`)**: Compiles the app for Windows and zips the release folder (`Avelo-Windows.zip`).
3. **Build Android (`build-android`)**: Compiles the app for Android and generates the APK (`Avelo-Android.apk`). This job is marked to continue on error, meaning if the Android build fails (e.g. due to Gradle incompatibility), the pipeline will still successfully release Linux and Windows.
4. **Create Release (`release`)**: Once all builds are complete, this job downloads the artifacts and publishes a GitHub Release with the binaries attached.

## How to trigger builds

There are three ways the pipeline is triggered:
1. **Push to `main`**: Any code pushed to the `main` branch will automatically compile the artifacts and upload them to the workflow run page. It will *not* create a GitHub Release.
2. **Pushing a version tag (`v*`)**: Pushing a git tag (e.g., `git push origin v1.0.0`) triggers a full build and *automatically* creates a public GitHub Release with the packaged assets.
3. **Manual Trigger (`workflow_dispatch`)**: Go to the "Actions" tab on GitHub, select "Build and Release Avelo", and click "Run workflow".

## Version Tags vs Artifacts

- **Artifacts**: Artifacts are temporary zip/tar files attached to a specific *run* of the workflow. They expire after a set time (usually 90 days) and are meant for testing or internal distribution. Every time the pipeline runs, it generates artifacts.
- **GitHub Releases**: Releases are permanent milestones attached to a specific version of the code. They are public-facing and contain the finalized binaries. Releases are *only* created when you push a tag like `v1.2.0`.

## How to create a Release

1. Commit your final code changes:
   ```bash
   git add .
   git commit -m "feat: new kanban board"
   ```
2. Tag the commit with the new version number:
   ```bash
   git tag v0.7.0
   ```
3. Push the commit and the tag to GitHub:
   ```bash
   git push origin main
   git push origin v0.7.0
   ```
4. The GitHub Action will start. Once it finishes (~5-10 minutes), the new version will appear under the "Releases" section of the repository with the binaries ready for download.

## Troubleshooting

- **Android Build Fails**: If the Android job fails, it's often due to an outdated Gradle wrapper incompatible with the runner's Java 17 version. You can update it locally by running `cd android && ./gradlew wrapper --gradle-version 7.6.2` and pushing the changes.
- **Release Job Fails**: Ensure that `permissions: contents: write` is correctly set in the workflow file, as the action requires permission to create the release on your behalf.
- **Missing Artifacts**: If a build fails to compile, the artifact upload step will be skipped. Click into the failed job (e.g., `build-linux`) in the Actions tab to view the exact Flutter compilation error.
