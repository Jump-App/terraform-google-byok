output "granted_members" {
  description = "Every principal granted access by this module, with the role it received."
  value = {
    for system, email in var.encrypter_decrypter_members :
    system => {
      member = "serviceAccount:${email}"
      role   = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
    }
  }
}
