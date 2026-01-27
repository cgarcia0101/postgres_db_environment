FROM postgres:17.5

# Install pgrep (procps) and openssh-client
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    procps \
    openssh-client && \
    # Clean up apt cache to reduce image size
    rm -rf /var/lib/apt/lists/*

# Keep the default PostgreSQL entrypoint
ENTRYPOINT ["docker-entrypoint.sh"]

# Default command to run PostgreSQL
CMD ["postgres"]