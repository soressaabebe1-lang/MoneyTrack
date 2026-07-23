from flask import Flask
from sqlalchemy import inspect, text

from project.models import db


def create_app():
    app = Flask(__name__)
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///transactions.db'
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    app.json.sort_keys = False
    db.init_app(app)

    from project.transaction.routes import transaction_bp
    app.register_blueprint(transaction_bp)

    with app.app_context():
        db.create_all()

        inspector = inspect(db.engine)
        if 'transaction' in inspector.get_table_names():
            columns = [column['name'] for column in inspector.get_columns('transaction')]
            if 'occurred_at' not in columns:
                db.session.execute(text("ALTER TABLE transaction ADD COLUMN occurred_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP"))
                db.session.execute(text("UPDATE transaction SET occurred_at = datetime(CURRENT_TIMESTAMP) WHERE occurred_at IS NULL"))
                db.session.commit()

    return app
