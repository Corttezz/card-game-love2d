import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'med5d.py'), encoding='utf-8').read().replace('import edl5', 'import edl6 as edl5')
exec(compile(src, 'med6', 'exec'))
