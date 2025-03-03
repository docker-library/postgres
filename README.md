# https://github.com/docker-library/postgres

## Maintained by: [the PostgreSQL Docker Community](https://github.com/docker-library/postgres)

This is the Git repo of the [Docker "Official Image"](https://github.com/docker-library/official-images#what-are-official-images) for [`postgres`](https://hub.docker.com/_/postgres/) (not to be confused with any official `postgres` image provided by `postgres` upstream). See [the Docker Hub page](https://hub.docker.com/_/postgres/) for the full readme on how to use this Docker image and for information regarding contributing and issues.

The [full image description on Docker Hub](https://hub.docker.com/_/postgres/) is generated/maintained over in [the docker-library/docs repository](https://github.com/docker-library/docs), specifically in [the `postgres` directory](https://github.com/docker-library/docs/tree/master/postgres).

## Versioning Warning:

### Pin a digest to avoid breaking changes
Docker "Official Images" use tags that correspond to the version of the application they run (in our case, Postgres) and therefore do not typically have any way of indicating changes (even breaking changes) to the image configuration in their tags or "version numbers".  Because of this, it is highly recommended that you "pin" a specific SHA digest of this image wherever it is used if you need to avoid breaking changes.

The digest for every tag is available on Docker Hub.  For instance, if you visit the [tags page for Postgres](https://hub.docker.com/_/postgres?tab=tags), and click on "12.2" you will see the sha256-digest for the most recent build of "12.2" at the top of the page.  This can be used to pin your image reference to that specific build of the image so that nothing will ever change in your environment unless you explicitly update it.  For instance, in a Docker Compose configuration, you might use something like:

```yaml
# docker-compose.yaml
version: '3.3'
services:
  db:
    image: postgres:12.2@sha256:b2f01d9d6928992adc1b96cc57ea350ecd131f9f580961c4a95fc8c58553e3b5
    ...
```

Note: This also prevents you from receiving important security and bug-fix updates, so you'll have to remember to update the digest yourself on a regular basis.  Choose your poison wisely ;)

## See a change merged here that doesn't show up on Docker Hub yet?

For more information about the full official images change lifecycle, see [the "An image's source changed in Git, now what?" FAQ entry](https://github.com/docker-library/faq#an-images-source-changed-in-git-now-what).

For outstanding `postgres` image PRs, check [PRs with the "library/postgres" label on the official-images repository](https://github.com/docker-library/official-images/labels/library%2Fpostgres). For the current "source of truth" for [`postgres`](https://hub.docker.com/_/postgres/), see [the `library/postgres` file in the official-images repository](https://github.com/docker-library/official-images/blob/master/library/postgres).

<!-- THIS FILE IS GENERATED BY https://github.com/docker-library/docs/blob/master/generate-repo-stub-readme.sh -->
