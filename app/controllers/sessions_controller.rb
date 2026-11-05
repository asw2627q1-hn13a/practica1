class SessionsController < ApplicationController
  def new
    # automaticament fa render de "app/views/sessions/new.html.erb"
  end

  def create
    return_to = session[:return_to]   # per poder redirigir l'usuari a la pàgina que volia visitar després del login

    user = User.from_omniauth(request.env["omniauth.auth"])
    reset_session
    session[:user_id] = user.id

    path = return_to || root_path     # per defecte redirigeix cap al root
    redirect_to(path, notice: "Sessió iniciada")  # cal millorar la notificació en un futur (de moment no desapareix)
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Sessió tancada"
  end

  def failure
    redirect_to(login_path, alert: "No s'ha pogut iniciar sessió") # cal millorar l'alerta
  end
end