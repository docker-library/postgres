sudo docker build -t pg_14_base .
sudo docker tag pg_14_base jinhongc/pg_14_base:latest
sudo docker push jinhongc/pg_14_base:latest
#sudo docker login # jinhongc
