# Changelog

## [0.3.0](https://github.com/exalsius/exalsius-workspace-hub/compare/jupyter-notebook-v0.2.0...jupyter-notebook-v0.3.0) (2026-07-07)


### Features

* add juypter-notebook workspace helm chart ([747246f](https://github.com/exalsius/exalsius-workspace-hub/commit/747246f5f9e32f55465657565f7351fcff056d4b))
* add log-streaming labels to main components of workspaces offered to users ([#49](https://github.com/exalsius/exalsius-workspace-hub/issues/49)) ([3e0bb87](https://github.com/exalsius/exalsius-workspace-hub/commit/3e0bb871c77a107f95f5555d87f11baaa220562f))
* remove ephemeral storage from all templates except diloco ([#55](https://github.com/exalsius/exalsius-workspace-hub/issues/55)) ([971162a](https://github.com/exalsius/exalsius-workspace-hub/commit/971162a2b7e6ddbc8f3f87bc84f83239eb4b63de))
* restructure helm values and add validation ([#52](https://github.com/exalsius/exalsius-workspace-hub/issues/52)) ([fed09c3](https://github.com/exalsius/exalsius-workspace-hub/commit/fed09c323b16e4c0fc172e7ce757da7b3561fc92))


### Bug Fixes

* adapt diloco-chart etcd-dependency; refactor all workspace values ([#46](https://github.com/exalsius/exalsius-workspace-hub/issues/46)) ([af996c7](https://github.com/exalsius/exalsius-workspace-hub/commit/af996c76957f55c4e0b374762274f3c665f82c91))
* add helper functions to truncate resource names to 63 chars ([628135b](https://github.com/exalsius/exalsius-workspace-hub/commit/628135b7400c88de8fcc70248d2fd19d9189a442))
* also remove enablePVCDeletion from schema ([2ef3841](https://github.com/exalsius/exalsius-workspace-hub/commit/2ef3841384731637c378c72e71f9d996604d9220))
* change imagepullpolicy of main workspaces ([#61](https://github.com/exalsius/exalsius-workspace-hub/issues/61)) ([202ce97](https://github.com/exalsius/exalsius-workspace-hub/commit/202ce9731870834990a701f838e93ac7bbc01ec5))
* helm chart validations ([#56](https://github.com/exalsius/exalsius-workspace-hub/issues/56)) ([db7712b](https://github.com/exalsius/exalsius-workspace-hub/commit/db7712beb9167f44f2704d66b79608daa5652383))
* **jupyter:** convert gpuCount string value to int ([1b46428](https://github.com/exalsius/exalsius-workspace-hub/commit/1b46428a0e360c75bfaac65c8665429211290d79))
* **jupyter:** do not request nvidia runtime when requested gpus=0 ([#83](https://github.com/exalsius/exalsius-workspace-hub/issues/83)) ([f4740be](https://github.com/exalsius/exalsius-workspace-hub/commit/f4740be5679931e37badd6a832d981b5c316310e))
* **juypter:** change juypter notebook docker image ([a94197f](https://github.com/exalsius/exalsius-workspace-hub/commit/a94197feb72fc6caa9571b81778d25550adb6972))
* **marimo:** remove enablePVCDeletion from required values ([788a28a](https://github.com/exalsius/exalsius-workspace-hub/commit/788a28a99a611ddc40df4827d23db938fcafa72a))
* remove deprecated pvcDeletion value ([f23cc73](https://github.com/exalsius/exalsius-workspace-hub/commit/f23cc73668c43805c12858b62a3ec7de0fb890f4))
* remove nodeSelector for jupyter and only use nvidia as runtime class when a gpu is used ([55243a8](https://github.com/exalsius/exalsius-workspace-hub/commit/55243a8b6e718ad057bdd5113ac5ffc48d014c27))
* renamings to fix camelcase / snakecase conversion ([9a921da](https://github.com/exalsius/exalsius-workspace-hub/commit/9a921dada6ea3be26f84492bfc9f36bd21f343dc))
* streamlined value naming across all workspaces and set sane defaults ([#3](https://github.com/exalsius/exalsius-workspace-hub/issues/3)) ([856a91d](https://github.com/exalsius/exalsius-workspace-hub/commit/856a91dc33b247d42403b66f22ff287aee89e3f8))
* use string values for helm chart ([18e7021](https://github.com/exalsius/exalsius-workspace-hub/commit/18e7021262d597593cdd6afdef614cc8a8584b6d))
