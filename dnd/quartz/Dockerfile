FROM node:22-slim
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /quartz
RUN git clone --depth 1 https://github.com/jackyzha0/quartz.git .
COPY quartz.config.ts .
RUN npm ci
EXPOSE 8080
CMD ["npx", "quartz", "build", "--serve", "--directory", "/content", "--port", "8080"]
