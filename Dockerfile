# Stage 1: Build Flutter web
FROM ghcr.io/cirruslabs/flutter:stable AS build

ARG APP_ENV=production
ARG SUPABASE_URL
ARG SUPABASE_PUBLISHABLE_KEY

WORKDIR /app
COPY . .

RUN flutter pub get
RUN flutter build web --release \
    --dart-define=APP_ENV=${APP_ENV} \
    --dart-define=SUPABASE_URL=${SUPABASE_URL} \
    --dart-define=SUPABASE_PUBLISHABLE_KEY=${SUPABASE_PUBLISHABLE_KEY}

# Stage 2: Serve with nginx
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
