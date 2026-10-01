#########################################################################
# Jump BYOK — customer-applied configuration
#
# Applied by the customer, in the customer's own Google Cloud project,
# against a key the customer owns. Jump does not run this.
#
# Today the whole of BYOK setup is key grants, so this root module wraps a
# single submodule. Additional concerns are added as further submodules
# behind their own variables, so that this remains the one entry point a
# customer consumes.
#########################################################################

module "cmek_grants" {
  source = "./modules/cmek-grants"

  crypto_key_id               = var.crypto_key_id
  encrypter_decrypter_members = merge(var.jump_service_agents, var.additional_identities)
}
