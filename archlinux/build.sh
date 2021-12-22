#!/bin/bash
PACKER_LOG=1 packer build -only=parallels-iso template.json
sha2 packer_parallels.box