# Makefile for Terraform VPC Configuration

.PHONY: help init plan apply destroy validate fmt clean

# Default target
help:
	@echo "Available targets:"
	@echo "  init      - Initialize Terraform"
	@echo "  validate  - Validate Terraform configuration"
	@echo "  fmt       - Format Terraform files"
	@echo "  plan      - Create Terraform execution plan"
	@echo "  apply     - Apply Terraform configuration"
	@echo "  destroy   - Destroy Terraform-managed infrastructure"
	@echo "  clean     - Clean up Terraform files"
	@echo "  help      - Show this help message"

# Initialize Terraform
init:
	@echo "Initializing Terraform..."
	terraform init

# Validate configuration
validate:
	@echo "Validating Terraform configuration..."
	terraform validate

# Format Terraform files
fmt:
	@echo "Formatting Terraform files..."
	terraform fmt -recursive

# Create execution plan
plan:
	@echo "Creating Terraform execution plan..."
	terraform plan

# Apply configuration
apply:
	@echo "Applying Terraform configuration..."
	terraform apply

# Destroy infrastructure
destroy:
	@echo "Destroying Terraform-managed infrastructure..."
	terraform destroy

# Clean up terraform files
clean:
	@echo "Cleaning up Terraform files..."
	rm -rf .terraform/
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate
	rm -f terraform.tfstate.backup
	rm -f *.tfplan

# Setup (init + validate + fmt)
setup: init validate fmt
	@echo "Setup complete!"

# Quick deploy (fmt + plan + apply)
deploy: fmt plan apply
	@echo "Deployment complete!"