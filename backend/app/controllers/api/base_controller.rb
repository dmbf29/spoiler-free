module Api
  # Shared behaviour for all JSON API controllers.
  class BaseController < ApplicationController
    rescue_from ActiveRecord::RecordNotFound do
      render json: { error: "not_found" }, status: :not_found
    end
  end
end
