module Companies
  module Recruiting
    class JobsController < ApplicationController
      def index
        @jobs = current_company.jobs
      end

      def edit; end

      def create
        head :ok
      end
    end
  end
end
