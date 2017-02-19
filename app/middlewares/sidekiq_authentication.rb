# frozen_string_literal: true
class SidekiqAuthentication
  include Rails.application.routes.url_helpers

  def initialize(app)
    @app = app
  end

  def call(env)
    if active_admin_session?(env)
      @app.call(env)
    else
      redirect_to admin_login_path
    end
  end

  private

  def active_admin_session?(env)
    Rack::Request.new(env).session[AdminSession::NAME]
  end

  def redirect_to(path)
    [302, { "Location" => path }, []]
  end
end