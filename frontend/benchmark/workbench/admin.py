from django.contrib import admin

from .models import Program, Benchmark, Result, ErrorCategory

admin.site.register(Program)
admin.site.register(Benchmark)
admin.site.register(Result)
admin.site.register(ErrorCategory)
