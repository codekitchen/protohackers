
```bash
bundle exec stackprof run --raw --out prof1.dump -- ruby --yjit ./9_job_centre.rb
ruby 9/stress.rb
stackprof --d3-flamegraph prof1.dump > fg.html
open fg.html
```
