from project import create_app

app = create_app()


@app.route('/health', methods=['GET'])
def health_check():

    
    return {"status": "healthy"}, 200
if __name__ == '__main__':
    app.run(debug=True)