# pythonocc-nodejs

## About

Dockerfile for an image with [`pythonocc-core`](https://github.com/tpaviot/pythonocc-core) and Node.js ... prepared and ready to go.

It is so far I can see the very first pythonocc Node.js docker image out there. 🎉🥂

Be aware, I built it around my very own use case (which includes having a screen for taking screenshots of loaded models).

Still, it might not be the final solution for you.
Feel free to adapt it to your needs.

You'll find a built version of it [on dockerhub](https://hub.docker.com/repository/docker/kiiurib/pythonocc-nodejs).

Also, if there is a better way to do it, please let me know.


## In your `Dockerfile`

    FROM kiiurib/pythonocc-nodejs:latest
    ...


## Versions

- python 3.9.16
- node.js 19.6.1, npm 9.5.0
- OpenCascade and pythonocc-core 7.7.0
