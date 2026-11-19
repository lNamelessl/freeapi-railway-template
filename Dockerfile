# FreeAPI Hub on Railway — pinned build of hiteshchoudhary/apihub
# Upstream commit: 3163bf09d9ee23e29378c402ae4d581e544d6c9f (2026-10-26, apihub 1.3.1)
# This Dockerfile mirrors upstream's Dockerfile at that commit verbatim
# (same base image family, same steps); the vendored source lives in apihub/
# with its ISC license in apihub/LICENSE.md. Base image is digest-pinned for
# reproducible builds.
FROM node:24-alpine@sha256:116b800c3754b440ee0aa3ed2f20f5bf3d99a554bfd9adeea09ea8017f6e85f5

RUN mkdir -p /usr/src/freeapi && chown -R node:node /usr/src/freeapi

WORKDIR /usr/src/freeapi

# Copy package json and yarn lock only to optimise the image building
COPY apihub/package.json apihub/yarn.lock ./

# copy prepare.js prior. It will be executed after package installation and before the rest of the source lands
COPY apihub/prepare.js ./

USER node

RUN yarn install --pure-lockfile

COPY --chown=node:node apihub/ .

EXPOSE 8080

CMD [ "node", "src/index.js" ]
