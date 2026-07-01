from __future__ import annotations

from functools import wraps
from typing import Any, Callable, TypeVar

from flask import (
    Flask,
    flash,
    jsonify,
    redirect,
    render_template,
    request,
    session,
    url_for,
)

from config import load_config
from services import auth_service, creature_service, crossbreed_service, history_service, lab_service, mutation_service, rating_service, task_service
from services.oracle import ServiceError, check_connection


ViewFunc = TypeVar("ViewFunc", bound=Callable[..., Any])


def create_app() -> Flask:
    config = load_config()
    app = Flask(__name__)
    app.config["SECRET_KEY"] = config.secret_key

    def login_required(view: ViewFunc) -> ViewFunc:
        @wraps(view)
        def wrapped(*args: Any, **kwargs: Any) -> Any:
            if not session.get("session_token"):
                flash("Выполните вход, чтобы открыть этот раздел.", "warning")
                return redirect(url_for("login"))
            return view(*args, **kwargs)

        return wrapped  # type: ignore[return-value]

    @app.context_processor
    def inject_context() -> dict[str, Any]:
        return {
            "is_authenticated": bool(session.get("session_token")),
            "current_lab_id": session.get("current_lab_id"),
        }

    def selected_lab_id() -> int | None:
        try:
            lab_id = int(session.get("current_lab_id") or 0)
        except (TypeError, ValueError):
            session.pop("current_lab_id", None)
            return None
        return lab_id or None

    @app.route("/")
    def index() -> Any:
        if session.get("session_token"):
            if session.get("current_lab_id"):
                return redirect(url_for("dashboard"))
            return redirect(url_for("labs"))
        return redirect(url_for("login"))

    @app.route("/register", methods=["GET", "POST"])
    def register() -> Any:
        if request.method == "POST":
            username = request.form.get("username", "").strip()
            login = request.form.get("login", "").strip()
            password = request.form.get("password", "")

            if not username or not login or not password:
                flash("Заполните имя, логин и пароль.", "error")
                return render_template("register.html", username=username, login=login)

            try:
                auth_service.register_user(username=username, login=login, password=password)
            except ServiceError as exc:
                flash(str(exc), "error")
                return render_template("register.html", username=username, login=login)

            flash("Пользователь зарегистрирован. Теперь можно войти.", "success")
            return redirect(url_for("login"))

        return render_template("register.html")

    @app.route("/login", methods=["GET", "POST"])
    def login() -> Any:
        if request.method == "POST":
            login_value = request.form.get("login", "").strip()
            password = request.form.get("password", "")

            if not login_value or not password:
                flash("Введите логин и пароль.", "error")
                return render_template("login.html", login=login_value)

            try:
                token = auth_service.login_user(login=login_value, password=password)
            except ServiceError as exc:
                flash(str(exc), "error")
                return render_template("login.html", login=login_value)

            if not token:
                flash("Неверный логин или пароль.", "error")
                return render_template("login.html", login=login_value)

            session.clear()
            session["session_token"] = token
            session["login"] = login_value
            flash("Вход выполнен.", "success")
            return redirect(url_for("labs"))

        return render_template("login.html")

    @app.route("/logout", methods=["GET", "POST"])
    def logout() -> Any:
        token = session.get("session_token")
        if token:
            try:
                auth_service.logout_user(token)
            except ServiceError as exc:
                flash(str(exc), "warning")
        session.clear()
        flash("Вы вышли из системы.", "success")
        return redirect(url_for("login"))

    @app.route("/labs", methods=["GET", "POST"])
    @login_required
    def labs() -> Any:
        token = str(session["session_token"])

        if request.method == "POST":
            action = request.form.get("action")
            try:
                if action == "create":
                    lab_id = lab_service.start_new_lab(token)
                    session["current_lab_id"] = lab_id
                    flash(f"Лаборатория #{lab_id} создана через package API.", "success")
                    return redirect(url_for("dashboard"))

                if action == "open":
                    lab_id = int(request.form.get("lab_id", "0"))
                    lab_service.load_lab(token, lab_id)
                    session["current_lab_id"] = lab_id
                    flash(f"Лаборатория #{lab_id} открыта.", "success")
                    return redirect(url_for("dashboard"))

                flash("Неизвестное действие.", "error")
            except (TypeError, ValueError):
                flash("Некорректный идентификатор лаборатории.", "error")
            except ServiceError as exc:
                flash(str(exc), "error")

        try:
            labs_rows = lab_service.list_user_labs(token)
        except ServiceError as exc:
            flash(str(exc), "error")
            labs_rows = []

        return render_template("labs.html", labs=labs_rows)

    @app.route("/dashboard")
    @login_required
    def dashboard() -> Any:
        token = str(session["session_token"])
        lab_id = selected_lab_id()
        if not lab_id:
            flash("Сначала откройте лабораторию.", "warning")
            return redirect(url_for("labs"))

        try:
            stats = lab_service.get_lab_stats(token, lab_id)
        except ServiceError as exc:
            session.pop("current_lab_id", None)
            flash(str(exc), "error")
            return redirect(url_for("labs"))

        return render_template("dashboard.html", stats=stats, lab_id=lab_id)

    @app.route("/creatures")
    @login_required
    def creatures() -> Any:
        token = str(session["session_token"])
        lab_id = selected_lab_id()
        if not lab_id:
            flash("Сначала выберите лабораторию.", "warning")
            return redirect(url_for("labs"))

        try:
            creatures_rows = creature_service.get_creatures(token, lab_id)
        except ServiceError as exc:
            flash(str(exc), "error")
            return redirect(url_for("labs"))

        return render_template("creatures.html", creatures=creatures_rows, lab_id=lab_id)

    @app.route("/creatures/<int:creature_id>")
    @login_required
    def creature_detail(creature_id: int) -> Any:
        token = str(session["session_token"])
        lab_id = selected_lab_id()
        if not lab_id:
            flash("Сначала выберите лабораторию.", "warning")
            return redirect(url_for("labs"))

        try:
            creature = creature_service.get_creature_detail(token, lab_id, creature_id)
            if not creature:
                flash("Существо не найдено в текущей лаборатории.", "warning")
                return redirect(url_for("creatures"))
            genotype = creature_service.get_genotype(token, creature_id, lab_id)
        except ServiceError as exc:
            flash(str(exc), "error")
            return redirect(url_for("creatures"))

        return render_template(
            "creature_detail.html",
            creature=creature,
            genotype=genotype,
            lab_id=lab_id,
        )

    @app.route("/tasks", methods=["GET", "POST"])
    @login_required
    def tasks() -> Any:
        token = str(session["session_token"])
        lab_id = selected_lab_id()
        if not lab_id:
            flash("Сначала выберите лабораторию.", "warning")
            return redirect(url_for("labs"))

        if request.method == "POST":
            action = request.form.get("action", "")
            try:
                task_id = int(request.form.get("task_id", "0"))
                creature_id = int(request.form.get("creature_id", "0"))
                if task_id <= 0 or creature_id <= 0:
                    raise ValueError

                if action == "check":
                    result = task_service.check_task(token, lab_id, task_id, creature_id)
                    if result:
                        flash("Существо подходит под заказ клиента.", "success")
                    else:
                        flash("Пока не подходит: backend не подтвердил выполнение заказа.", "warning")
                    return redirect(url_for("tasks"))

                if action == "complete":
                    result = task_service.complete_task(token, lab_id, task_id, creature_id)
                    if result["is_completed"]:
                        flash(
                            "Заказ выполнен. Кошелёк: "
                            f"{result['wallet_after']}, рейтинг: {result['rating_after']}.",
                            "success",
                        )
                    else:
                        flash("Заказ не выполнен: backend не подтвердил выбранное существо.", "warning")
                    return redirect(url_for("tasks"))

                flash("Неизвестное действие с заказом.", "error")
            except (TypeError, ValueError):
                flash("Выберите заказ и существо перед действием.", "error")
            except ServiceError as exc:
                flash(str(exc), "error")

            return redirect(url_for("tasks"))

        try:
            tasks_rows = task_service.get_tasks(token, lab_id)
            creatures_rows = creature_service.get_creatures(token, lab_id)
        except ServiceError as exc:
            flash(str(exc), "error")
            return redirect(url_for("dashboard"))

        active_tasks = [
            task for task in tasks_rows
            if str(task.get("task_status", "")).upper() == "ACTIVE"
        ]
        completed_tasks = [
            task for task in tasks_rows
            if str(task.get("task_status", "")).upper() == "COMPLETED"
        ]
        other_tasks = [
            task for task in tasks_rows
            if task not in active_tasks and task not in completed_tasks
        ]

        return render_template(
            "tasks.html",
            active_tasks=active_tasks,
            completed_tasks=completed_tasks,
            other_tasks=other_tasks,
            creatures=creatures_rows,
            lab_id=lab_id,
        )

    @app.route("/crossbreed", methods=["GET", "POST"])
    @login_required
    def crossbreed() -> Any:
        token = str(session["session_token"])
        lab_id = selected_lab_id()
        if not lab_id:
            flash("Сначала выберите лабораторию.", "warning")
            return redirect(url_for("labs"))

        selected_parent1 = request.form.get("parent1_id", "")
        selected_parent2 = request.form.get("parent2_id", "")
        offspring_name = request.form.get("offspring_name", "").strip()
        preview_options: list[dict[str, Any]] = []

        try:
            creatures_rows = creature_service.get_creatures(token, lab_id)
        except ServiceError as exc:
            flash(str(exc), "error")
            return redirect(url_for("dashboard"))

        if request.method == "POST":
            action = request.form.get("action", "")
            try:
                parent1_id = int(selected_parent1 or "0")
                parent2_id = int(selected_parent2 or "0")
                if parent1_id <= 0 or parent2_id <= 0:
                    raise ValueError

                if action == "preview":
                    preview_options = crossbreed_service.preview_offspring_options(
                        token,
                        lab_id,
                        parent1_id,
                        parent2_id,
                        options_count=3,
                    )
                    if len(preview_options) == 3:
                        flash("Backend вернул 3 preview-варианта потомства без изменения лаборатории.", "success")
                    else:
                        flash(f"Backend вернул {len(preview_options)} preview-вариантов.", "warning")

                elif action == "create":
                    if not offspring_name:
                        flash("Введите имя потомка перед созданием.", "error")
                    else:
                        offspring_id = crossbreed_service.crossbreed(
                            token,
                            lab_id,
                            parent1_id,
                            parent2_id,
                            offspring_name,
                        )
                        flash(f"Потомок создан через backend package: #{offspring_id}.", "success")
                        if offspring_id:
                            return redirect(url_for("creature_detail", creature_id=offspring_id))
                        return redirect(url_for("creatures"))
                else:
                    flash("Неизвестное действие скрещивания.", "error")
            except (TypeError, ValueError):
                flash("Выберите двух разных родителей перед действием.", "error")
            except ServiceError as exc:
                flash(str(exc), "error")

        return render_template(
            "crossbreed.html",
            creatures=creatures_rows,
            preview_options=preview_options,
            selected_parent1=selected_parent1,
            selected_parent2=selected_parent2,
            offspring_name=offspring_name,
            lab_id=lab_id,
        )
    @app.route("/mutations", methods=["GET", "POST"])
    @login_required
    def mutations() -> Any:
        token = str(session["session_token"])
        lab_id = selected_lab_id()
        if not lab_id:
            flash("Сначала выберите лабораторию.", "warning")
            return redirect(url_for("labs"))

        if request.method == "POST":
            action = request.form.get("action", "")
            try:
                if action == "buy_mutation":
                    mutation_id = int(request.form.get("mutation_id", "0"))
                    if mutation_id <= 0:
                        raise ValueError
                    result = mutation_service.buy_mutation(token, lab_id, mutation_id)
                    if result:
                        flash("Мутация куплена через backend package. Кошелёк обновлён backend-логикой.", "success")
                    else:
                        flash("Мутация не куплена: backend вернул отказ, чаще всего из-за нехватки средств.", "warning")
                    return redirect(url_for("mutations"))

                if action == "apply_mutation":
                    creature_id = int(request.form.get("creature_id", "0"))
                    mutation_id = int(request.form.get("mutation_id", "0"))
                    if creature_id <= 0 or mutation_id <= 0:
                        raise ValueError
                    mutation_service.apply_mutation(token, lab_id, creature_id, mutation_id)
                    flash("Мутация применена. Генотип, фенотип и рейтинг обновлены backend-логикой.", "success")
                    return redirect(url_for("creature_detail", creature_id=creature_id))

                if action == "apply_mutagen":
                    creature_id = int(request.form.get("creature_id", "0"))
                    mutagen_type = request.form.get("mutagen_type", "").strip().upper()
                    if creature_id <= 0 or mutagen_type not in {"RADIATION", "CHEMICAL"}:
                        raise ValueError
                    new_creature_id = mutation_service.apply_mutagen(token, lab_id, creature_id, mutagen_type)
                    flash("Мутагент применён. Проверьте изменения рейтинга, кошелька и список существ.", "success")
                    if new_creature_id:
                        return redirect(url_for("creature_detail", creature_id=new_creature_id))
                    return redirect(url_for("mutations"))

                flash("Неизвестное действие с мутациями.", "error")
            except (TypeError, ValueError):
                flash("Выберите существо и мутацию перед действием.", "error")
            except ServiceError as exc:
                flash(str(exc), "error")

            return redirect(url_for("mutations"))

        try:
            stats = lab_service.get_lab_stats(token, lab_id)
            creatures_rows = creature_service.get_creatures(token, lab_id)
            shop_rows = mutation_service.get_mutation_shop(token, lab_id)
        except ServiceError as exc:
            flash(str(exc), "error")
            return redirect(url_for("dashboard"))

        return render_template(
            "mutations.html",
            stats=stats,
            creatures=creatures_rows,
            mutations=shop_rows,
            lab_id=lab_id,
        )
    @app.route("/experiments")
    @login_required
    def experiments() -> Any:
        token = str(session["session_token"])
        lab_id = selected_lab_id()
        if not lab_id:
            flash("Сначала выберите лабораторию.", "warning")
            return redirect(url_for("labs"))

        try:
            rows = history_service.get_experiment_history(token, lab_id)
        except ServiceError as exc:
            flash(str(exc), "error")
            return redirect(url_for("dashboard"))

        return render_template("experiments.html", experiments=rows, lab_id=lab_id)

    @app.route("/rating-events")
    @login_required
    def rating_events() -> Any:
        token = str(session["session_token"])
        lab_id = selected_lab_id()
        if not lab_id:
            flash("Сначала выберите лабораторию.", "warning")
            return redirect(url_for("labs"))

        try:
            rows = rating_service.get_rating_events(token, lab_id)
        except ServiceError as exc:
            flash(str(exc), "error")
            return redirect(url_for("dashboard"))

        return render_template("rating_events.html", events=rows, lab_id=lab_id)
    @app.route("/about-requirements")
    def about_requirements() -> Any:
        return render_template("about_requirements.html")
    @app.route("/health")
    def health() -> Any:
        database = check_connection()
        status = 200 if database["ok"] else 503
        return jsonify({"app": "ok", "database": database}), status

    @app.errorhandler(404)
    def not_found(_: Exception) -> Any:
        return render_template("error.html", title="Страница не найдена", message="Такой страницы нет."), 404

    @app.errorhandler(500)
    def internal_error(_: Exception) -> Any:
        return render_template("error.html", title="Ошибка", message="Произошла внутренняя ошибка."), 500

    return app


app = create_app()


if __name__ == "__main__":
    cfg = load_config()
    app.run(host=cfg.host, port=cfg.port, debug=cfg.debug)