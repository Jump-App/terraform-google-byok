variable "jump_deployment_location" {
  description = <<-EOT
    The Cloud KMS location your Jump deployment requires: us-central1 (United
    States), northamerica-northeast1 (Canada) or europe-west1 (Europe). Your
    key must live in this location.
  EOT

  type = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.jump_deployment_location))
    error_message = "jump_deployment_location must be a Cloud KMS location name, lowercase, such as europe-west1."
  }
}

variable "crypto_key_id" {
  description = <<-EOT
    Full resource ID of the Cloud KMS key Jump should be allowed to use.

    Format: projects/<project>/locations/<location>/keyRings/<ring>/cryptoKeys/<key>

    The key stays in your project under your control. Jump never receives key
    material — only permission to call encrypt/decrypt on this key. Removing
    that permission, disabling the key version, or destroying the key ends
    Jump's ability to read your data. See "Revoking access" in the README.
  EOT

  type = string

  validation {
    condition     = can(regex("^projects/[^/]+/locations/[^/]+/keyRings/[^/]+/cryptoKeys/[^/]+$", var.crypto_key_id))
    error_message = "crypto_key_id must be a full key resource ID of the form projects/<project>/locations/<location>/keyRings/<ring>/cryptoKeys/<key>."
  }

  validation {
    condition     = try(split("/", var.crypto_key_id)[3], null) == var.jump_deployment_location
    error_message = "crypto_key_id must name a key in ${var.jump_deployment_location}, the Cloud KMS location of your Jump deployment. The key supplied is in ${try(split("/", var.crypto_key_id)[3], "an unparseable location")}."
  }
}

variable "jump_service_agents" {
  description = <<-EOT
    Jump's Google-managed service agents that encrypt and decrypt with the
    key, keyed by the system each one belongs to. These are the Cloud SQL,
    Cloud Storage and Compute Engine service agents of Jump's production
    project, and are the same for every Jump deployment, so the defaults are
    correct for every customer. Override only if Jump asks you to.

    Each entry receives roles/cloudkms.cryptoKeyEncrypterDecrypter on this key
    and nothing else.
  EOT

  type = map(string)

  default = {
    cloudsql = "service-228790252436@gcp-sa-cloud-sql.iam.gserviceaccount.com"
    storage  = "service-228790252436@gs-project-accounts.iam.gserviceaccount.com"
    compute  = "service-228790252436@compute-system.iam.gserviceaccount.com"
  }

  validation {
    condition     = length(var.jump_service_agents) > 0
    error_message = "jump_service_agents must contain at least one service account."
  }

  validation {
    condition = alltrue([
      for email in values(var.jump_service_agents) :
      can(regex("^[a-zA-Z0-9][a-zA-Z0-9_.-]*@[a-zA-Z0-9-]+\\.iam\\.gserviceaccount\\.com$", email))
    ])
    error_message = "Every value in jump_service_agents must be a Google Cloud service account address ending in .iam.gserviceaccount.com. Pass the bare address, with no \"serviceAccount:\" prefix."
  }
}

variable "additional_identities" {
  description = <<-EOT
    Further service accounts that need to encrypt and decrypt with the key,
    beyond Jump's own service agents, keyed by the system each one belongs to
    (for example "turbopuffer", for the vector store that holds your
    embeddings). Jump supplies these during onboarding.

    Each entry receives roles/cloudkms.cryptoKeyEncrypterDecrypter on this key
    and nothing else.
  EOT

  type    = map(string)
  default = {}

  validation {
    condition = alltrue([
      for email in values(var.additional_identities) :
      can(regex("^[a-zA-Z0-9][a-zA-Z0-9_.-]*@[a-zA-Z0-9-]+\\.iam\\.gserviceaccount\\.com$", email))
    ])
    error_message = "Every value in additional_identities must be a Google Cloud service account address ending in .iam.gserviceaccount.com. Pass the bare address, with no \"serviceAccount:\" prefix."
  }

  validation {
    condition     = length(setintersection(keys(var.additional_identities), keys(var.jump_service_agents))) == 0
    error_message = "additional_identities must not reuse a key already in jump_service_agents (${join(", ", keys(var.jump_service_agents))}); each system is granted once."
  }
}
