package ht.henrique.mazebank.model.database;

import lombok.Data;

@Data
public class BaseCollection {

    private String collection;
    private String database;
    private String dataSource;
    private Projection projection;
}
