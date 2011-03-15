import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

public class ClientExample {

    public static void main(String... args) {
        try {
            Class.forName("org.hsqldb.jdbcDriver");
        } catch (Exception e) {
            System.out.println("ERROR: failed to load HSQLDB JDBC driver.");
            e.printStackTrace();
            return;
        }

        Connection c = null;
        try {
            c = DriverManager.getConnection("jdbc:hsqldb:hsql://localhost/bdays", "sa", "");
            if (c != null) {
                c.close();
            }
        } catch (SQLException e) {
            System.out.println("ERROR: failed to connect to server.");
            e.printStackTrace();
            return;
        }

    }
}
