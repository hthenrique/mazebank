package ht.henrique.mazebank.model.reposiory;

import ht.henrique.mazebank.model.database.Transaction;
import org.springframework.data.repository.CrudRepository;

import java.util.List;

public interface TransactionRepository extends CrudRepository<Transaction, Long> {
}
