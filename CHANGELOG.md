# Changelog

## [2.6.0](https://github.com/Qumulo/qumulo-terraform-oci/compare/qumulo-terraform-oci-v2.5.1...qumulo-terraform-oci-v2.6.0) (2026-06-15)


### Features

* add alias provider for deploying iam resources into home region ([a772627](https://github.com/Qumulo/qumulo-terraform-oci/commit/a772627b41c8cd737264fdacfde66dc71a483efa))
* move dynamic group into identity domain when selected ([27e0a1f](https://github.com/Qumulo/qumulo-terraform-oci/commit/27e0a1f60936cd4cbb12a845a2b5f3f0781078ce))

## [2.5.1](https://github.com/Qumulo/qumulo-terraform-oci/compare/qumulo-terraform-oci-v2.5.0...qumulo-terraform-oci-v2.5.1) (2026-06-08)


### Bug Fixes

* add lifecycle rules to prevent repeated deployements of identity domain resources ([c2e99ba](https://github.com/Qumulo/qumulo-terraform-oci/commit/c2e99ba66971e50685dea82af549e180c6b0effc))
* convert stack completion timeout to variable ([90e8f29](https://github.com/Qumulo/qumulo-terraform-oci/commit/90e8f29bcbc964cc73f1c1963fdec49f9bba2212))
* corrected node count and floating ip count limits ([45deb7e](https://github.com/Qumulo/qumulo-terraform-oci/commit/45deb7eb3e508938389ffacb463f059d0fc41999))
* update variable validation in core module ([00f352b](https://github.com/Qumulo/qumulo-terraform-oci/commit/00f352b4b8ae3384900ecef9d3a9a827d21a346d))

## [2.5.0](https://github.com/Qumulo/qumulo-terraform-oci/compare/qumulo-terraform-oci-v2.4.0...qumulo-terraform-oci-v2.5.0) (2026-05-29)


### Features

* add move block for identity policy ([7a1bb03](https://github.com/Qumulo/qumulo-terraform-oci/commit/7a1bb03aa80b01e31db35b9f61791eae10f1a937))
* add moved blocks for compatibility ([b0caa17](https://github.com/Qumulo/qumulo-terraform-oci/commit/b0caa1738c3546e23c596c95cece16b5ce0249b4))
* add tags to domain identity resources ([304feac](https://github.com/Qumulo/qumulo-terraform-oci/commit/304feac00b4ab9dc899589fb4824412cf31b68de))
* create persistent storage access model variable ([38ea5d4](https://github.com/Qumulo/qumulo-terraform-oci/commit/38ea5d4de258ee4a244725d1ff2621340744d85f))
* update identity policy name to prevent redeployment event ([0060197](https://github.com/Qumulo/qumulo-terraform-oci/commit/0060197c2b00d377b074dc5a0aac80f8afb12506))
* update OCI provider version ([9bc67fd](https://github.com/Qumulo/qumulo-terraform-oci/commit/9bc67fd13452bc0d658ab0888d1b719af77a3a21))


### Bug Fixes

* refactor Customer Secret Key names ([e2f371b](https://github.com/Qumulo/qumulo-terraform-oci/commit/e2f371b070786d5dd5e05d3e17522ea589456f7d))
* syntax error ([56d05e4](https://github.com/Qumulo/qumulo-terraform-oci/commit/56d05e40ae43d06a9e8870f410ec44a742f152af))
* update doc ([3e13b41](https://github.com/Qumulo/qumulo-terraform-oci/commit/3e13b41b81eed82ce687c07e2c55bd76028c181c))
* update OCI provider versions in all modules ([9c7a9f5](https://github.com/Qumulo/qumulo-terraform-oci/commit/9c7a9f5f1dc57debbc0a1196eb010077ccf669dd))

## [2.4.0](https://github.com/Qumulo/qumulo-terraform-oci/compare/qumulo-terraform-oci-v2.3.0...qumulo-terraform-oci-v2.4.0) (2026-05-20)


### Features

* update version to 2.4.0 ([2b13bcd](https://github.com/Qumulo/qumulo-terraform-oci/commit/2b13bcd30c69d129796aaee35cc87f1ffa09a572))
* update version to 2.4.0 ([74e97df](https://github.com/Qumulo/qumulo-terraform-oci/commit/74e97dfd809495d15d77111568fea07ca97e1cb4))

## [2.3.0](https://github.com/Qumulo/qumulo-terraform-oci/compare/qumulo-terraform-oci-v2.2.0...qumulo-terraform-oci-v2.3.0) (2026-04-21)


### Features

* automate releases via release-please (baseline v2.3.0) ([9b0bff0](https://github.com/Qumulo/qumulo-terraform-oci/commit/9b0bff0d6a8b7a955ae7a1546f7bbbbf40d67bd8))
* baseline v2.3.0 release ([53e4354](https://github.com/Qumulo/qumulo-terraform-oci/commit/53e4354efbce7321b7d352f0139022fb541ae56b))


### Bug Fixes

* propagated required versions for oracle/oci to improve compatibility ([32b425b](https://github.com/Qumulo/qumulo-terraform-oci/commit/32b425b05f97f9ff8171ca74213fea8b7dca24e5))
* virtual-network-family permissions from `manage` to `use` ([9d1ca58](https://github.com/Qumulo/qumulo-terraform-oci/commit/9d1ca587d2f052fc32b9063bf32b6139b6c37646))
* virtual-network-family permissions from `manage` to `use` ([87d4550](https://github.com/Qumulo/qumulo-terraform-oci/commit/87d4550bb66f8dd64d9ab6162fc8e5b89213e398))
