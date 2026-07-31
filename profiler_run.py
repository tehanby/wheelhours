from profiler import app

app.wsgi_app = ProfilerMiddleware(app.wsgi_app, restrictions=[30])
app.run(debug=True)
