package ht.henrique.mazebank.model.reposiory;

import ht.henrique.mazebank.model.database.User;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface UserRepository extends CrudRepository<User, Long> {

    @Query(value = "SELECT * FROM user_table WHERE user_email = :userEmail", nativeQuery = true)
    List<User> findByUserEmail(@Param("userEmail") String userEmail);

}
