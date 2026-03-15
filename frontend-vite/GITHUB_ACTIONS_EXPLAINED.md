# GitHub Actions Explanation for `deploy.yaml`

This guide explains your current workflow file:

- Path: `.github/workflows/deploy.yaml`
- Goal: run CI checks for the frontend and deploy to AWS Elastic Beanstalk on pushes to `main`

---

## The Workflow You Have

```yaml
name: Deploy frontend
on:
  push:
    branches:
      - main

jobs:
  build:
    runs-on: ubuntu-latest
    env:
      APP_DIR: frontend-vite
      DEPLOY_ZIP: deploy.zip
    steps:
      - uses: actions/checkout@v6
      - run: docker login -u ${{ secrets.DOCKER_USERNAME }} -p ${{ secrets.DOCKER_PASSWORD }}
      - run: docker build -t markeybass/react-test-vite -f Dockerfile.dev .
        working-directory: ${{ env.APP_DIR }}
      - run: docker run --rm -e CI=true markeybass/react-test-vite npm test

      - name: Generate deployment package
        run: zip -r ${{ env.DEPLOY_ZIP }} . -x '*.git*'
        working-directory: ${{ env.APP_DIR }}
      - name: Deploy to EB
        uses: einaregilsson/beanstalk-deploy@v21
        with:
          aws_access_key: ${{ secrets.AWS_ACCESS_KEY }}
          aws_secret_key: ${{ secrets.AWS_SECRET_KEY }}
          application_name: frontend
          environment_name: Frontend-env
          existing_bucket_name: elasticbeanstalk-us-east-1-923445559289
          region: us-east-1
          version_label: ${{ github.sha }}
          deployment_package: ${{ env.APP_DIR }}/${{ env.DEPLOY_ZIP }}
```

---

## Line-by-Line Conceptual Breakdown

### 1) Workflow metadata and trigger

- `name: Deploy frontend`  
  This is the display name shown in the GitHub Actions UI.

- `on: push: branches: [main]`  
  The workflow runs automatically when code is pushed to the `main` branch.

Why this matters:
- You are defining a CD pipeline tied to your production branch.
- Any commit to `main` attempts test + deploy.

---

### 2) Job-level settings and runner

- `jobs:` starts one or more jobs.
- `build:` is the job ID (internal identifier).
- `runs-on: ubuntu-latest` picks a GitHub-hosted Linux VM.
- `env.APP_DIR: frontend-vite` stores your monorepo app path once and reuses it in steps.
- `env.DEPLOY_ZIP: deploy.zip` stores the artifact name so it is not duplicated in multiple lines.

Important behavior:
- A job runs in a fresh ephemeral runner.
- Files from your repo are not present until checkout happens.

---

### 3) Steps in order

Steps execute sequentially in the same job environment.

#### `- uses: actions/checkout@v6`

- This action checks out your repo code into the runner workspace.
- Without this, Docker build/test and zip commands would not find your files.

From Context7/GitHub docs:
- `uses` references an action (`owner/repo@version`).
- `checkout` is usually the first step in CI workflows.

#### `- run: docker login -u ... -p ...`

- Logs into Docker Hub using repository secrets.
- `${{ secrets.DOCKER_USERNAME }}` and `${{ secrets.DOCKER_PASSWORD }}` come from GitHub encrypted secrets.

Why it exists:
- Needed if image pull/push to private resources is required.

Security note:
- Passing password with `-p` can expose it in process arguments.
- Safer pattern is `--password-stdin`.

#### `- run: docker build -t markeybass/react-test-vite -f Dockerfile.dev .` with `working-directory: ${{ env.APP_DIR }}`

- Builds an image from `Dockerfile.dev`.
- Tags the image as `markeybass/react-test-vite`.
- `.` means current directory is build context, and because `working-directory` is `frontend-vite`, Docker can resolve `COPY package.json .` correctly.

#### `- run: docker run --rm -e CI=true markeybass/react-test-vite npm test`

- Starts a container from the built image.
- Runs tests (`npm test`) inside that container.
- `CI=true` typically makes test runners non-interactive and stricter for CI.
- `--rm` auto-removes the test container after it exits.

This gives you a reproducible CI test environment.

---

### 4) Packaging for Elastic Beanstalk

#### `Generate deployment package`

- `zip -r ${{ env.DEPLOY_ZIP }} . -x '*.git*'` creates a deployment zip archive.
- Excludes `.git`-related files.
- Because it runs with `working-directory: ${{ env.APP_DIR }}`, the zip is created inside `frontend-vite`.

What it does in pipeline terms:
- Produces an artifact (`frontend-vite/deploy.zip`) that the deployment action can upload.

---

### 5) Deploying with marketplace action

#### `uses: einaregilsson/beanstalk-deploy@v21`

- Invokes a third-party GitHub Action that deploys to AWS Elastic Beanstalk.
- `with:` passes action inputs.

Inputs explained:
- `aws_access_key`, `aws_secret_key`: AWS credentials from GitHub secrets.
- `application_name`: EB application name (`frontend`).
- `environment_name`: target EB environment (`Frontend-env`).
- `existing_bucket_name`: S3 bucket EB uses for app versions.
- `region`: AWS region.
- `version_label: ${{ github.sha }}`: version identifier = commit SHA.
- `deployment_package: ${{ env.APP_DIR }}/${{ env.DEPLOY_ZIP }}`: artifact path in this monorepo layout.

Why `github.sha` is useful:
- Every deployment maps directly to a commit, improving traceability and rollback clarity.

---

## Core GitHub Actions Syntax You’re Using

- `uses`: run a reusable action.
- `run`: run shell commands directly on the runner.
- `${{ ... }}`: expression syntax.
- `secrets.*`: secure secret values.
- `github.sha`: commit hash of the workflow-triggering revision.

From Context7 docs, these are canonical GitHub Actions contexts and workflow syntax patterns.

---

## End-to-End Flow (What Happens on Push to `main`)

1. GitHub starts workflow `Deploy frontend`.
2. Creates Ubuntu runner.
3. Checks out repo.
4. Logs into Docker.
5. Builds app image from `frontend-vite/Dockerfile.dev` by using `working-directory`.
6. Runs tests inside container.
7. Creates `frontend-vite/deploy.zip` for deployment.
8. Deploys that zip to AWS Elastic Beanstalk with a commit-SHA version label.

---

## Good Improvements to Learn Next

If you want to level this workflow up, next concepts to study are:

1. Use `--password-stdin` for Docker login (safer secret handling).
2. Keep actions updated and/or pin to commit SHA for stronger supply chain safety.
3. Add `permissions:` explicitly (least privilege).
4. Add dependency caching or Docker layer caching for faster builds.
5. Add branch protection so only successful workflows can merge to `main`.

