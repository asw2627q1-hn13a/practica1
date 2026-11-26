module Api
  module V1
    # API-13: hide and unhide submissions for the api-key user.
    class HiddenController < BaseController
      before_action :set_submission

      # POST /api/v1/submissions/:submission_id/hidden
      def create
        return already_hidden if @submission.hides.exists?(user: current_user)

        @submission.hides.create!(user: current_user)
        render json: { hidden: true }, status: :created
      rescue ActiveRecord::RecordNotUnique
        already_hidden
      end

      # DELETE /api/v1/submissions/:submission_id/hidden
      def destroy
        hide = @submission.hides.find_by(user: current_user)
        return render_error(404, "This submission is not hidden") unless hide

        hide.destroy!
        head :no_content
      end

      private

      def set_submission
        @submission = Submission.find(params[:submission_id])
      end

      def already_hidden
        render_error(409, "This submission is already hidden")
      end
    end
  end
end
