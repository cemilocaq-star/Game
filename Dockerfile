FROM barichello/godot-ci:4.4.1

WORKDIR /game
COPY . .
EXPOSE 2456/udp

CMD ["godot", "--headless", "--path", "/game", "--", "--server"]
