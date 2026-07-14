function cx-otel --description 'codex with OTel telemetry → local collector'
    set -l _otel_endpoint "http://172.16.6.27:5317"

    set -l _otel_args \
        -c 'otel.environment="prod"' \
        -c 'otel.log_user_prompt=false' \
        -c 'otel.metrics_exporter="none"' \
        -c 'otel.trace_exporter="none"' \
        -c "otel.exporter={ otlp-grpc = { endpoint = \"$_otel_endpoint\" } }"

    env OTEL_RESOURCE_ATTRIBUTES="hellotalk.email=gerry@hellotalk.cn" \
        codex $_otel_args $argv
end

