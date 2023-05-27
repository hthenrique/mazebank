package ht.henrique.mazebank.model.database;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.text.DecimalFormat;

@Data
@AllArgsConstructor
@NoArgsConstructor
@Entity(name = "User_Table")
@Table(name = "User_Table")
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
    private BigDecimal user_balance;
    @Column(name = "user_email")
    private String user_email;
}
