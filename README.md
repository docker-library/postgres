# https://github.com/docker-library/postgres

## Maintained by: [the PostgreSQL Docker Community](https://github.com/docker-library/postgres)

This is the Git repo of the [Docker "Official Image"](https://github.com/docker-library/official-images#what-are-official-images) for [`postgres`](https://hub.docker.com/_/postgres/) (not to be confused with any official `postgres` image provided by `postgres` upstream). See [the Docker Hub page](https://hub.docker.com/_/postgres/) for the full readme on how to use this Docker image and for information regarding contributing and issues.

The [full image description on Docker Hub](https://hub.docker.com/_/postgres/) is generated/maintained over in [the docker-library/docs repository](https://github.com/docker-library/docs), specifically in [the `postgres` directory](https://github.com/docker-library/docs/tree/master/postgres).

## Versioning Warning:

### Pin a digest to avoid breaking changes
Docker "Official Images" use tags that correspond to the version of the application they contain an image of (in our case, Porstgres), and therefore do not typically have any way of indicating changes (even breaking changes) to the image configuration.  Therefore it is highly recommended that you "pin" a specific sha-digest of this image wherer it is used if you need to avoid breaking changes.

The digest for every tag is available on Docker Hub.  For instance, if you visit the [tags page for Postgres](https://hub.docker.com/_/postgres?tab=tags), and click on "12.2" you will see the sha-digest for the most recent build of "12.2" at the top of the page.  This can be used to pin your image reference to that specific build of the image so that nothing will ever change in your environment unless you explicitly update it.  For instnace, in a Docker Compose configuration, you might use something like:

```yaml
# docker-compose.yaml
version: '3.3'
services:
  db:
    image: postgres:12.2@sha256:b2f01d9d6928992adc1b96cc57ea350ecd131f9f580961c4a95fc8c58553e3b5
    ...
```

Note: This also precludes you from receiving important security and bug-fix updates, so you'll have to remember to update the digest yourself on a regular basis.  Choose your poison wisely ;)

## See a change merged here that doesn't show up on Docker Hub yet?

For more information about the full official images change lifecycle, see [the "An image's source changed in Git, now what?" FAQ entry](https://github.com/docker-library/faq#an-images-source-changed-in-git-now-what).

For outstanding `postgres` image PRs, check [PRs with the "library/postgres" label on the official-images repository](https://github.com/docker-library/official-images/labels/library%2Fpostgres). For the current "source of truth" for [`postgres`](https://hub.docker.com/_/postgres/), see [the `library/postgres` file in the official-images repository](https://github.com/docker-library/official-images/blob/master/library/postgres).

---

-	[![build status badge](https://img.shields.io/travis/docker-library/postgres/master.svg?label=Travis%20CI)](https://travis-ci.org/docker-library/postgres/branches)
-	[![build status badge](https://img.shields.io/jenkins/s/https/doi-janky.infosiftr.net/job/update.sh/job/postgres.svg?label=Automated%20update.sh)](https://doi-janky.infosiftr.net/job/update.sh/job/postgres)

| Build | Status | Badges | (per-arch) |
|:-:|:-:|:-:|:-:|
| [![amd64 build status badge](https://img.shields.io/jenkins/s/https/doi-janky.infosiftr.net/job/multiarch/job/amd64/job/postgres.svg?label=amd64)](https://doi-janky.infosiftr.net/job/multiarch/job/amd64/job/postgres) | [![arm32v5 build status badge](https://img.shields.io/jenkins/s/https/doi-janky.infosiftr.net/job/multiarch/job/arm32v5/job/postgres.svg?label=arm32v5)](https://doi-janky.infosiftr.net/job/multiarch/job/arm32v5/job/postgres) | [![arm32v6 build status badge](https://img.shields.io/jenkins/s/https/doi-janky.infosiftr.net/job/multiarch/job/arm32v6/job/postgres.svg?label=arm32v6)](https://doi-janky.infosiftr.net/job/multiarch/job/arm32v6/job/postgres) | [![arm32v7 build status badge](https://img.shields.io/jenkins/s/https/doi-janky.infosiftr.net/job/multiarch/job/arm32v7/job/postgres.svg?label=arm32v7)](https://doi-janky.infosiftr.net/job/multiarch/job/arm32v7/job/postgres) |
| [![arm64v8 build status badge](https://img.shields.io/jenkins/s/https/doi-janky.infosiftr.net/job/multiarch/job/arm64v8/job/postgres.svg?label=arm64v8)](https://doi-janky.infosiftr.net/job/multiarch/job/arm64v8/job/postgres) | [![i386 build status badge](https://img.shields.io/jenkins/s/https/doi-janky.infosiftr.net/job/multiarch/job/i386/job/postgres.svg?label=i386)](https://doi-janky.infosiftr.net/job/multiarch/job/i386/job/postgres) | [![ppc64le build status badge](https://img.shields.io/jenkins/s/https/doi-janky.infosiftr.net/job/multiarch/job/ppc64le/job/postgres.svg?label=ppc64le)](https://doi-janky.infosiftr.net/job/multiarch/job/ppc64le/job/postgres) | [![s390x build status badge](https://img.shields.io/jenkins/s/https/doi-janky.infosiftr.net/job/multiarch/job/s390x/job/postgres.svg?label=s390x)](https://doi-janky.infosiftr.net/job/multiarch/job/s390x/job/postgres) |
| [![put-shared build status badge](https://img.shields.io/jenkins/s/https/doi-janky.infosiftr.net/job/put-shared/job/light/job/postgres.svg?label=put-shared)](https://doi-janky.infosiftr.net/job/put-shared/job/light/job/postgres) |

<!-- THIS FILE IS GENERATED BY https://github.com/docker-library/docs/blob/master/generate-repo-stub-readme.sh -->
