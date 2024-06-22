# Use a versão específica da sintaxe do Dockerfile
# Veja mais detalhes em https://docs.docker.com/go/dockerfile-reference/
# Este comentário é ignorado quando a imagem é criada.

################################################################################

# Crie uma etapa para resolver e baixar as dependências.
FROM maven:3.8.4-jdk-11 AS build

WORKDIR /app

# Copie apenas o arquivo pom.xml inicial para aproveitar o cache do Docker
COPY pom.xml .

# Baixe as dependências como uma etapa separada para aproveitar o cache do Docker.
RUN mvn dependency:go-offline -B

# Copie todos os arquivos do projeto e compile o aplicativo
COPY src src/
RUN mvn package -DskipTests

################################################################################

# Crie uma etapa final para executar o aplicativo compilado
FROM openjdk:11-jre-slim

WORKDIR /app

# Copie o JAR compilado da etapa anterior
COPY --from=build /app/target/*.jar mazebank.jar

# Exponha a porta onde o aplicativo Spring Boot estará escutando
EXPOSE 8080

# Especifica o comando de entrada para executar o aplicativo
ENTRYPOINT ["java", "-jar", "mazebank.jar"]