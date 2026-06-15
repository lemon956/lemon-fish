function cc-otel --description 'claude with OTel telemetry → local collector'
    argparse --ignore-unknown h/help no-proxy -- $argv
    or return
    set -lx CLAUDE_CODE_ENABLE_TELEMETRY 1
    set -lx CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 1
    set -lx OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE cumulative
    set -lx OTEL_METRICS_EXPORTER otlp
    set -lx OTEL_LOGS_EXPORTER otlp
    set -lx OTEL_EXPORTER_OTLP_PROTOCOL grpc
    set -lx OTEL_EXPORTER_OTLP_ENDPOINT https://usage.hellotalk.cloud
    set -lx OTEL_RESOURCE_ATTRIBUTES hellotalk.email=gerry@hellotalk.cn
    set -lx OTEL_LOG_USER_PROMPTS 0
    set -lx OTEL_LOG_TOOL_CONTENT 0
    set -lx OTEL_LOG_TOOL_DETAILS 0
    set -lx OTEL_METRICS_INCLUDE_SESSION_ID false
    set -lx OTEL_METRIC_EXPORT_INTERVAL 1000
    set -lx OTEL_LOGS_EXPORT_INTERVAL 1000
    set -lx OTEL_TRACES_EXPORT_INTERVAL 1000
    claude $argv
end