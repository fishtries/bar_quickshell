import os
import runpy

runpy.run_path(
    os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "modules",
        "localsend",
        "qs-localsend.py",
    ),
    run_name="__main__",
)
