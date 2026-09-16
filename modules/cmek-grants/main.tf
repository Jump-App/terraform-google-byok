#########################################################################
# CMEK grants
#
# google_kms_crypto_key_iam_member is deliberate: it is additive, so it
# adds exactly these bindings and leaves every other policy binding on the
# key untouched.
#########################################################################

resource "google_kms_crypto_key_iam_member" "encrypter_decrypter" {
  # Keyed by system rather than by address, so replacing the address for a
  # given system is an update in place rather than a churn of resource
  # addresses.
  for_each = var.encrypter_decrypter_members

  crypto_key_id = var.crypto_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${each.value}"
}
