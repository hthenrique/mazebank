package ht.henrique.mazebank.model.database;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
@Entity(name = "users")
@Table(name = "users")
public class User implements Projection{

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "uid")
    private Integer uid;
    @Column(name = "user_name")
    private String user_name;
    @Column(name = "user_pass")
    private String user_pass;
    @Column(name = "user_balance")
    private Integer user_balance;
    @Column(name = "user_account_key")
    private String user_account_key;
}
