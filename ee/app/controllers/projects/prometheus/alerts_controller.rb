module Projects
  module Prometheus
    class AlertsController < Projects::ApplicationController
      respond_to :json

      protect_from_forgery except: [:notify]

      before_action :authorize_read_prometheus_alerts!, except: [:notify]
      before_action :authorize_admin_project!, except: [:notify]
      before_action :alert, only: [:update, :show, :destroy]

      def index
        alerts = prometheus_alerts.reorder(id: :asc)

        render json: serialize_as_json(alerts)
      end

      def show
        render json: serialize_as_json(alert)
      end

      def notify
        NotificationService.new.async.prometheus_alerts_fired(project, params["alerts"])

        head :ok
      end

      def create
        @alert = prometheus_alerts.create(create_alert_params)

        if @alert.persisted?
          schedule_prometheus_update!

          render json: serialize_as_json(@alert)
        else
          render_404
        end
      end

      def update
        if alert.update(update_alert_params)
          schedule_prometheus_update!

          render json: serialize_as_json(alert)
        else
          head :no_content
        end
      end

      def destroy
        if alert.destroy
          schedule_prometheus_update!

          head :ok
        else
          head :no_content
        end
      end

      private

      def create_alert_params
        alerts_params = params.permit(:operator, :threshold, :prometheus_metric_id)
        resolve_operator(alerts_params)
      end

      def update_alert_params
        alerts_params = params.permit(:operator, :threshold)
        resolve_operator(alerts_params)
      end

      def resolve_operator(params)
        if operator = params[:operator].presence
          params[:operator] = PrometheusAlert.operator_to_enum(operator)
        end

        params
      end

      def schedule_prometheus_update!
        ::Clusters::Applications::ScheduleUpdateService.new(application, project).execute
      end

      def serialize_as_json(alert_obj)
        serializer.represent(alert_obj)
      end

      def serializer
        PrometheusAlertSerializer.new(project: project, current_user: current_user)
      end

      def alert
        @alert ||= prometheus_alerts.find_by(prometheus_metric_id: params[:id]) || render_404
      end

      def application
        @application ||= alert.environment.cluster_prometheus_adapter
      end

      def prometheus_alerts
        project.prometheus_alerts.for_environment(params[:environment_id])
      end
    end
  end
end
