FROM node:14.17.3

RUN apt update
RUN apt install -y curl

WORKDIR /web/frontend

RUN npm install

EXPOSE 3000

CMD ["npm", "start"]