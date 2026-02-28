# Makefile for Terraform VPC Configuration with Git State Management

.PHONY: help init plan apply destroy validate fmt clean git-pull git-push git-apply git-destroy

# Default target
help:
	@echo "Available targets:"
	@echo "  init         - Initialize Terraform"
	@echo "  validate     - Validate Terraform configuration" 
	@echo "  fmt          - Format Terraform files"
	@echo "  plan         - Create Terraform execution plan (with git pull)"
	@echo "  apply        - Apply Terraform configuration"
	@echo "  destroy      - Destroy Terraform-managed infrastructure"  
	@echo "  clean        - Clean up Terraform files (keeps state)"
	@echo "  git-pull     - Pull latest changes (run before tf operations)"
	@echo "  git-push     - Commit and push state changes"
	@echo "  git-apply    - Full workflow: pull, apply, commit, push"
	@echo "  git-destroy  - Full workflow: pull, destroy, commit, push"
	@echo "  help         - Show this help message"

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
plan: git-pull
	@echo "Creating Terraform execution plan..."
	terraform plan

# Apply configuration
apply:
	@echo "Applying Terraform configuration..."
	terraform apply

# Full git workflow for apply
git-apply: git-pull fmt
	@echo "Applying Terraform with full git workflow..."
	terraform apply
	$(MAKE) git-push

# Destroy infrastructure  
destroy:
	@echo "Destroying Terraform-managed infrastructure..."
	terraform destroy

# Full git workflow for destroy
git-destroy: git-pull
	@echo "Destroying Terraform with full git workflow..."
	terraform destroy
	$(MAKE) git-push

# Git operations
git-pull:
	@echo "Pulling latest changes from git..."
	git pull origin main

git-push:
	@echo "Committing and pushing state changes..."
	git add .
	git commit -m "Updated terraform state - $(shell date '+%Y-%m-%d %H:%M:%S')" || echo "No changes to commit"
	git push origin main

# Clean up terraform files (preserve state for git tracking)
clean:
	@echo "Cleaning up Terraform files (preserving state)..."
	rm -rf .terraform/
	rm -f .terraform.lock.hcl
	rm -f *.tfplan

# Setup (init + validate + fmt)
setup: init validate fmt
	@echo "Setup complete!"

# Quick deploy (fmt + plan + apply with git workflow)
deploy: git-pull fmt plan apply git-push
	@echo "Deployment with git workflow complete!"

# Full workflow with git management
full-deploy: setup git-apply
	@echo "Complete setup and deployment with git workflow finished!"