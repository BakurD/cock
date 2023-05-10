provider "{{cookiecutter.provider_name}}" {} 

module "Infrastructure" {
  source = "./infrastructure"
  vpc_cidr_block = "10.0.0.0/16"
  public_subnet_cidr = [
    "10.0.11.0/24",
    "10.0.21.0/24"
  ]
  private_subnet = "10.0.12.0/24"
  min_size = "{{cookiecutter.min_size}}"
  max_size = "{{cookiecutter.max_size}}"
  min_elb = "5"
}