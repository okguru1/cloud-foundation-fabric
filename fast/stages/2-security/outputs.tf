/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

locals {
  _output_kms_keys = concat(
    flatten([
      for location, mod in module.dev-sec-kms : [
        for name, id in mod.key_ids : {
          key = "dev-${name}:${location}"
          id  = id
        }
      ]
    ]),
    flatten([
      for location, mod in module.prod-sec-kms : [
        for name, id in mod.key_ids : {
          key = "prod-${name}:${location}"
          id  = id
        }
      ]
    ])
  )
  cas_ids = {
    dev = {
      for k, v in module.dev-sec-cas
      : k => {
        ca_pool_id = v.ca_pool_id
        ca_ids     = v.ca_ids
      }
    }
    prod = {
      for k, v in module.prod-sec-cas
      : k => {
        ca_pool_id = v.ca_pool_id
        ca_ids     = v.ca_ids
      }
    }
  }
  output_kms_keys = { for k in local._output_kms_keys : k.key => k.id }
  tfvars = {
    cas_ids  = local.cas_ids
    kms_keys = local.output_kms_keys
  }
}

resource "local_file" "tfvars" {
  for_each        = var.outputs_location == null ? {} : { 1 = 1 }
  file_permission = "0644"
  filename        = "${pathexpand(var.outputs_location)}/tfvars/2-security.auto.tfvars.json"
  content         = jsonencode(local.tfvars)
}

resource "google_storage_bucket_object" "tfvars" {
  bucket  = var.automation.outputs_bucket
  name    = "tfvars/2-security.auto.tfvars.json"
  content = jsonencode(local.tfvars)
}

output "kms_keys" {
  description = "KMS key ids."
  value       = local.output_kms_keys
}

output "tfvars" {
  description = "Terraform variable files for the following stages."
  sensitive   = true
  value       = local.tfvars
}
