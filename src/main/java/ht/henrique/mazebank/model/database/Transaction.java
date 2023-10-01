package ht.henrique.mazebank.model.database;


import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;



@Data
@AllArgsConstructor
@NoArgsConstructor
public class Transaction {

    private Integer tid;

    private Integer id_user_origin;

    private Integer id_user_destiny;

    private Float transaction_value;
}
