#!/bin/bash
PACKER_LOG=1 packer build -only=parallels-pvm template.json
sha2 packer_parallels.box