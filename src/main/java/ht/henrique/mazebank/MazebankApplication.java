package ht.henrique.mazebank;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.ComponentScan;

@SpringBootApplication
@ComponentScan({"ht.henrique.mazebank"})
public class MazebankApplication {
    public static void main(String[] args) {
        SpringApplication.run(MazebankApplication.class, args);
    }
}