plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Enforce consistent naming conventions
rule "terraform_naming_convention" {
  enabled = true

  variable {
    format = "snake_case"
  }

  output {
    format = "snake_case"
  }

  local {
    format = "snake_case"
  }
}

# Require descriptions on all variables and outputs
rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

# Require typed variables
rule "terraform_typed_variables" {
  enabled = true
}

# Warn on deprecated interpolation syntax
rule "terraform_deprecated_interpolation" {
  enabled = true
}

# Require required_version in every module
rule "terraform_required_version" {
  enabled = true
}

# Require required_providers with source and version
rule "terraform_required_providers" {
  enabled = true
}
