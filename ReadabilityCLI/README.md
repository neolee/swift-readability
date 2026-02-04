## Initial Tests

```shell
cat test.html | swift run ReadabilityCLI --text-only 2> /dev/null
```

```shell
curl -s https://soulhacker.me/posts/why-type-system-matters/ | swift run ReadabilityCLI --text-only 2> /dev/null
```