# frozen_string_literal: true

module Api::V1::Policies::Relationships
  class EntitlementsController < Api::V1::BaseController
    before_action :scope_to_current_account!
    before_action :require_active_subscription!
    before_action :authenticate_with_token!
    before_action :set_policy

    def index
      authorize @policy, :list_entitlements?

      @entitlements = policy_scope apply_scopes(@policy.entitlements)
      authorize @entitlements

      render jsonapi: @entitlements
    end

    def show
      authorize @policy, :show_entitlement?
      @entitlement = @policy.entitlements.find params[:id]

      render jsonapi: @entitlement
    end

    def attach
      authorize @policy, :attach_entitlement?
      @policy_entitlements = @policy.policy_entitlements

      entitlements = entitlement_params.fetch(:data).map do |entitlement|
        entitlement.merge(account_id: current_account.id)
      end

      @policy_entitlements.transaction do
        attached = @policy_entitlements.create!(entitlements)

        attached.each do |policy_entitlement|
          CreateWebhookEventService.new(
            event: 'policy.entitlement.attached',
            account: current_account,
            resource: policy_entitlement.entitlement
          ).execute
        end
      end
    end

    def detach
      authorize @policy, :detach_entitlement?
      @policy_entitlements = @policy.policy_entitlements

      entitlement_ids = entitlement_params.fetch(:data).collect { |e| e[:entitlement_id] }
      entitlements = @policy_entitlements.where(entitlement_id: entitlement_ids)

      if entitlements.size != entitlement_ids.size
        entitlement_ids_not_found = entitlement_ids - entitlements.collect(&:entitlement_id)

        entitlements.raise_record_not_found_exception!(
          entitlement_ids_not_found,
          entitlements.size,
          entitlement_ids.size
        )
      end

      @policy_entitlements.transaction do
        detached = @policy_entitlements.delete(entitlements)

        detached.each do |policy_entitlement|
          CreateWebhookEventService.new(
            event: 'policy.entitlement.detached',
            account: current_account,
            resource: policy_entitlement.entitlement
          ).execute
        end
      end
    end

    private

    def set_policy
      @policy = current_account.policies.find params[:policy_id]

      Keygen::Store::Request.store[:current_resource] = @policy
    end

    typed_parameters do
      options strict: true

      on :attach do
        param :data, type: :array do
          items type: :hash do
            param :type, type: :string, inclusion: %w[entitlement entitlements], transform: -> (k, v) { [] }
            param :id, type: :string, transform: -> (k, v) {
              [:entitlement_id, v]
            }
          end
        end
      end

      on :detach do
        param :data, type: :array do
          items type: :hash do
            param :type, type: :string, inclusion: %w[entitlement entitlements], transform: -> (k, v) { [] }
            param :id, type: :string, transform: -> (k, v) {
              [:entitlement_id, v]
            }
          end
        end
      end
    end
  end
end
