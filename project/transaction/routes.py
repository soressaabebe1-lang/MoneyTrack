from datetime import datetime

from flask import Blueprint, request, jsonify
from project.models import db, transaction
from sqlalchemy import or_

transaction_bp = Blueprint('transaction', __name__)


def _parse_occurred_at(data):
    if data.get('date') is None and data.get('time') is None:
        return datetime.utcnow()

    selected_date = None
    selected_time = None

    if data.get('date'):
        try:
            selected_date = datetime.strptime(data['date'], '%Y-%m-%d').date()
        except ValueError:
            raise ValueError('Date must be in YYYY-MM-DD format.')

    if data.get('time'):
        time_value = data['time']
        try:
            if len(time_value.split(':')) == 2:
                selected_time = datetime.strptime(time_value, '%H:%M').time()
        except ValueError:
            raise ValueError('Time must be in HH:MM format.')

    now = datetime.utcnow()
    final_date = selected_date or now.date()
    final_time = selected_time or now.time()
    return datetime.combine(final_date, final_time)


@transaction_bp.route('/transactions', methods=['POST'])
def create_transaction():
    data = request.get_json(silent=True)
    if data is None:
        data = request.form.to_dict()

    if not isinstance(data, dict):
        data = {}

    name = data.get('name')
    reason = data.get('reason')
    if not name or not reason:
        return jsonify({'error': 'Name and reason are required fields.'}), 400

    try:
        income = float(data.get('income', 0.0) or 0.0)
        expenses = float(data.get('expenses', 0.0) or 0.0)
    except (TypeError, ValueError):
        return jsonify({'error': 'Income and expenses must be numbers.'}), 400

    try:
        occurred_at = _parse_occurred_at(data)
    except ValueError as exc:
        return jsonify({'error': str(exc)}), 400

    new_transaction = transaction(
        name=data['name'],
        reason=data['reason'],
        income=income,
        expenses=expenses,
        occurred_at=occurred_at,
    )
    db.session.add(new_transaction)
    db.session.commit()
    return jsonify(new_transaction.to_dict()), 201

@transaction_bp.route('/transactions', methods=['GET'])
def get_transactions():
    transactions = transaction.query.all()
    return jsonify([t.to_dict() for t in transactions]), 200

@transaction_bp.route('/transactions/<int:transaction_id>', methods=['GET'])
def get_transaction(transaction_id): 
    transaction_obj = db.session.get(transaction, transaction_id)
    if not transaction_obj:
        return jsonify({'error': 'Transaction not found.'}), 404
    return jsonify(transaction_obj.to_dict()), 200

@transaction_bp.route('/transactions/<string:transaction_name>', methods=['GET'])
def get_transaction_by_name(transaction_name):
    transaction_obj = transaction.query.filter_by(name=transaction_name.strip().title()).first()
    if not transaction_obj:
        return jsonify({'error': 'Transaction not found.'}), 404
    return jsonify(transaction_obj.to_dict()), 200

@transaction_bp.route('/transactions/search/<string:search_term>', methods=['GET'])
def search_transactions(search_term):
    pattern = f"%{search_term.strip()}%"
    transactions = (
        transaction.query
        .filter(
            or_(
                transaction.name.ilike(pattern),
                transaction.reason.ilike(pattern),
            ),
        )
        .order_by(transaction.occurred_at.desc())
        .all()
    )
    return jsonify([t.to_dict() for t in transactions]), 200

@transaction_bp.route('/total_income', methods=['GET'])
def get_total_income(): 
    total_income = db.session.query(db.func.sum(transaction.income)).scalar() or 0.0
    return jsonify({'total_income': total_income}), 200

@transaction_bp.route('/total_expenses', methods=['GET'])
def get_total_expenses():   
    total_expenses = db.session.query(db.func.sum(transaction.expenses)).scalar() or 0.0
    return jsonify({'total_expenses': total_expenses}), 200

@transaction_bp.route('/net_balance', methods=['GET'])
def get_net_balance():
    total_income = db.session.query(db.func.sum(transaction.income)).scalar() or 0.0
    total_expenses = db.session.query(db.func.sum(transaction.expenses)).scalar() or 0.0
    net_balance = total_income - total_expenses
    return jsonify({'net_balance': net_balance}), 200

@transaction_bp.route('/total_income_by_name/<string:transaction_name>', methods=['GET'])
def get_total_income_by_name(transaction_name):
    pattern = f"%{transaction_name.strip()}%"
    total_income = (
        db.session.query(db.func.sum(transaction.income))
        .filter(transaction.name.ilike(pattern))
        .scalar()
        or 0.0
    )
    return jsonify({'total_income': total_income}), 200

@transaction_bp.route('/total_expenses_by_name/<string:transaction_name>', methods=['GET'])
def get_total_expenses_by_name(transaction_name):   
    pattern = f"%{transaction_name.strip()}%"
    total_expenses = (
        db.session.query(db.func.sum(transaction.expenses))
        .filter(transaction.name.ilike(pattern))
        .scalar()
        or 0.0
    )
    return jsonify({'total_expenses': total_expenses}), 200 

@transaction_bp.route('/net_balance_by_name/<string:transaction_name>', methods=['GET'])
def get_net_balance_by_name(transaction_name):  
    pattern = f"%{transaction_name.strip()}%"
    total_income = (
        db.session.query(db.func.sum(transaction.income))
        .filter(transaction.name.ilike(pattern))
        .scalar()
        or 0.0
    )
    total_expenses = (
        db.session.query(db.func.sum(transaction.expenses))
        .filter(transaction.name.ilike(pattern))
        .scalar()
        or 0.0
    )
    net_balance = total_income - total_expenses
    return jsonify({'net_balance': net_balance}), 200

@transaction_bp.route('/transactions/<int:transaction_id>', methods=['PUT'])
def update_transaction(transaction_id):
    transaction_obj = db.session.get(transaction, transaction_id)
    if not transaction_obj:
        return jsonify({'error': 'Transaction not found.'}), 404

    data = request.get_json(silent=True)
    if data is None:
        data = request.form.to_dict()

    if not isinstance(data, dict):
        data = {}

    name = data.get('name')
    reason = data.get('reason')
    if not name or not reason:
        return jsonify({'error': 'Name and reason are required fields.'}), 400

    try:
        income = float(data.get('income', 0.0) or 0.0)
        expenses = float(data.get('expenses', 0.0) or 0.0)
    except (TypeError, ValueError):
        return jsonify({'error': 'Income and expenses must be numbers.'}), 400

    try:
        occurred_at = _parse_occurred_at(data)
    except ValueError as exc:
        return jsonify({'error': str(exc)}), 400

    transaction_obj.name = data['name']
    transaction_obj.reason = data['reason']
    transaction_obj.income = income
    transaction_obj.expenses = expenses
    transaction_obj.occurred_at = occurred_at
    db.session.commit()
    return jsonify(transaction_obj.to_dict()), 200

@transaction_bp.route('/transactions/<int:transaction_id>', methods=['DELETE'])
def delete_transaction(transaction_id):
    transaction_obj = db.session.get(transaction, transaction_id)
    if not transaction_obj:
        return jsonify({'error': 'Transaction not found.'}), 404
    db.session.delete(transaction_obj)
    db.session.commit()
    return jsonify({'message': 'Transaction deleted successfully.'}), 200

