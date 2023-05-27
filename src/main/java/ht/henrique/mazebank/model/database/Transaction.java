package ht.henrique.mazebank.model.database;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;



@Data
@AllArgsConstructor
@NoArgsConstructor
@Entity(name = "Transactions_Table")
@Table(name = "Transactions_Table")
public class Transaction implements Projection {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "tid")
    private Integer tid;
    @Column(name = "id_user_origin")
    private Integer id_user_origin;
    @Column(name = "id_user_destiny")
    private Integer id_user_destiny;
    @Column(name = "transaction_value")
    private Float transaction_value;
}
