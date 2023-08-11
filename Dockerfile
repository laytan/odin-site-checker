FROM alpine:latest

WORKDIR /odin

ENV PATH "$PATH:/usr/lib/llvm14/bin:/odin"

RUN apk add --no-cache git bash make clang14 llvm14-dev musl-dev linux-headers openssl-libs-static && \
    git clone --depth=1 https://github.com/odin-lang/Odin . && \
    LLVM_CONFIG=llvm14-config make release_native

WORKDIR /app

COPY . .

RUN odin build . -o:speed -out:site-checker -extra-linker-flags:"-static -march=native"

FROM scratch

ARG SITES_TO_CHECK
ENV SITES_TO_CKECK=$SITES_TO_CHECK

ARG TELEGRAM_CHAT_ID
ENV TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID

ARG TELEGRAM_TOKEN
ENV TELEGRAM_TOKEN=$TELEGRAM_TOKEN

COPY --from=0 /app/site-checker /bin/site-checker

CMD ["/bin/site-checker"]
