from datetime import datetime

from flask_sqlalchemy import SQLAlchemy


db = SQLAlchemy()


class transaction(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50), nullable=False)
    reason = db.Column(db.String(100), nullable=False)
    income = db.Column(db.Float, nullable=False, default=0.0)
    expenses = db.Column(db.Float, nullable=False, default=0.0)
    occurred_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name.strip().title(),
            'reason': self.reason,
            'income': self.income,
            'expenses': self.expenses,
            'date': self.occurred_at.date().isoformat(),
            'time': self.occurred_at.time().strftime('%H:%M'),
            'occurred_at': self.occurred_at.isoformat(),
        }

