# Changelog

## [0.3.0](https://github.com/exalsius/exalsius-workspace-hub/compare/marimo-v0.2.0...marimo-v0.3.0) (2026-07-07)


### Features

* add log-streaming labels to main components of workspaces offered to users ([#49](https://github.com/exalsius/exalsius-workspace-hub/issues/49)) ([3e0bb87](https://github.com/exalsius/exalsius-workspace-hub/commit/3e0bb871c77a107f95f5555d87f11baaa220562f))
* add marimo workspace template ([dee4f1c](https://github.com/exalsius/exalsius-workspace-hub/commit/dee4f1c7f80db7e12f2c0c8a100930b9dc429962))
* add marimo workspace template ([40fa9e4](https://github.com/exalsius/exalsius-workspace-hub/commit/40fa9e474eabd5f66a965e73f4ddf21aeccdfab1))
* remove ephemeral storage from all templates except diloco ([#55](https://github.com/exalsius/exalsius-workspace-hub/issues/55)) ([971162a](https://github.com/exalsius/exalsius-workspace-hub/commit/971162a2b7e6ddbc8f3f87bc84f83239eb4b63de))
* restructure helm values and add validation ([#52](https://github.com/exalsius/exalsius-workspace-hub/issues/52)) ([fed09c3](https://github.com/exalsius/exalsius-workspace-hub/commit/fed09c323b16e4c0fc172e7ce757da7b3561fc92))
* use exalsius devpod marimo image ([#51](https://github.com/exalsius/exalsius-workspace-hub/issues/51)) ([fe5c3ae](https://github.com/exalsius/exalsius-workspace-hub/commit/fe5c3aeecf8b354e9b17eb5d2c15d9c9de3d55b7))


### Bug Fixes

* adapt diloco-chart etcd-dependency; refactor all workspace values ([#46](https://github.com/exalsius/exalsius-workspace-hub/issues/46)) ([af996c7](https://github.com/exalsius/exalsius-workspace-hub/commit/af996c76957f55c4e0b374762274f3c665f82c91))
* add helper functions to truncate resource names to 63 chars ([628135b](https://github.com/exalsius/exalsius-workspace-hub/commit/628135b7400c88de8fcc70248d2fd19d9189a442))
* add support for AMD GPUs in marimo workspace ([#22](https://github.com/exalsius/exalsius-workspace-hub/issues/22)) ([bfc74cd](https://github.com/exalsius/exalsius-workspace-hub/commit/bfc74cdfff8351ed625ee29ec26e4b08757eded3))
* add tokenPassword as a value for the marimo workspace ([77f02df](https://github.com/exalsius/exalsius-workspace-hub/commit/77f02df23cdbfa418ec7f07abb40da57d5e2ea39))
* add tokenPassword as a value for the marimo workspace ([c6595af](https://github.com/exalsius/exalsius-workspace-hub/commit/c6595afb769d3d88e67cde6ae23f3e232778e16e))
* also remove enablePVCDeletion from schema ([2ef3841](https://github.com/exalsius/exalsius-workspace-hub/commit/2ef3841384731637c378c72e71f9d996604d9220))
* change imagepullpolicy of main workspaces ([#61](https://github.com/exalsius/exalsius-workspace-hub/issues/61)) ([202ce97](https://github.com/exalsius/exalsius-workspace-hub/commit/202ce9731870834990a701f838e93ac7bbc01ec5))
* change workingDir of marimo workspace ([#21](https://github.com/exalsius/exalsius-workspace-hub/issues/21)) ([ed5ea3e](https://github.com/exalsius/exalsius-workspace-hub/commit/ed5ea3e83cc2df6ed12587fc9e11a373b8f1d237))
* helm chart validations ([#56](https://github.com/exalsius/exalsius-workspace-hub/issues/56)) ([db7712b](https://github.com/exalsius/exalsius-workspace-hub/commit/db7712beb9167f44f2704d66b79608daa5652383))
* **marimo:** add missing password secret ([604234d](https://github.com/exalsius/exalsius-workspace-hub/commit/604234df6ce875c56fd8ab8f7201e4fb9ce88afc))
* **marimo:** fix typo in template deployment ([9d1d9e9](https://github.com/exalsius/exalsius-workspace-hub/commit/9d1d9e95bdbc1c05b25735f64b46a9a2cc511ce4))
* **marimo:** re-use gpuVendor resources ([#24](https://github.com/exalsius/exalsius-workspace-hub/issues/24)) ([660dd46](https://github.com/exalsius/exalsius-workspace-hub/commit/660dd4618b0ddc3b14a5a829c3bdfe2f3dc7904f))
* **marimo:** remove enablePVCDeletion from required values ([788a28a](https://github.com/exalsius/exalsius-workspace-hub/commit/788a28a99a611ddc40df4827d23db938fcafa72a))
* **marimo:** support upper- and lowercase GPU vendors ([#25](https://github.com/exalsius/exalsius-workspace-hub/issues/25)) ([e1dc090](https://github.com/exalsius/exalsius-workspace-hub/commit/e1dc090a3e903f58b0f680f463372c974a5e7016))
* remove deprecated pvcDeletion value ([f23cc73](https://github.com/exalsius/exalsius-workspace-hub/commit/f23cc73668c43805c12858b62a3ec7de0fb890f4))
* rename gpuType to gpuVendor ([#23](https://github.com/exalsius/exalsius-workspace-hub/issues/23)) ([f2d1e62](https://github.com/exalsius/exalsius-workspace-hub/commit/f2d1e623b33676705468b2114b80b259547a0d29))
